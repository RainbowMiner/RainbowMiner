#!/usr/bin/env bash
# RainbowMiner Linux AMD sysfs overclock backend (development only).
# No PowerPlay table writes or SMU resets. Assumes no competing OC controller.
set -euo pipefail

bus=""
power_percent=""
core_max=""
mem_max=""
voltage_offset=""
dry_run=0
reset=0
replace_profile=0

usage() {
    echo "Usage: $0 --bus BB:DD [--power-percent 20..200] [--core-max MHz] [--mem-max MHz] [--voltage-offset signed-mV] [--reset] [--replace-profile] [--dry-run]" >&2
}

while (($#)); do
    case "$1" in
        --bus|--power-percent|--core-max|--mem-max|--voltage-offset)
            (($# >= 2)) || { usage; exit 2; }
            case "$1" in
                --bus) bus=$2 ;;
                --power-percent) power_percent=$2 ;;
                --core-max) core_max=$2 ;;
                --mem-max) mem_max=$2 ;;
                --voltage-offset) voltage_offset=$2 ;;
            esac
            shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        --reset) reset=1; shift ;;
        --replace-profile) replace_profile=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

if ((reset && replace_profile)); then
    echo "--reset and --replace-profile cannot be combined" >&2; exit 2
fi
if ((reset)) && [[ -n "$power_percent" || -n "$core_max" || -n "$mem_max" || -n "$voltage_offset" ]]; then
    echo "--reset cannot be combined with OC adjustments" >&2; exit 2
fi
[[ "$bus" =~ ^[[:xdigit:]]{2}:[[:xdigit:]]{2}$ ]] || { echo "Invalid AMD PCI bus id: $bus" >&2; exit 2; }
[[ -z "$power_percent" || "$power_percent" =~ ^[0-9]+$ ]] || { echo "Invalid AMD power percentage: $power_percent" >&2; exit 2; }
[[ -z "$core_max" || "$core_max" =~ ^[0-9]+$ ]] || { echo "Invalid AMD core maximum: $core_max" >&2; exit 2; }
[[ -z "$mem_max" || "$mem_max" =~ ^[0-9]+$ ]] || { echo "Invalid AMD memory maximum: $mem_max" >&2; exit 2; }
[[ -z "$voltage_offset" || "$voltage_offset" =~ ^-?[0-9]+$ ]] || { echo "Invalid AMD voltage offset: $voltage_offset" >&2; exit 2; }

if [[ -n "$power_percent" ]] && ((10#$power_percent < 20 || 10#$power_percent > 200)); then
    echo "Power limit must be 20..200 percent of the GPU default." >&2; exit 2
fi

# RainbowMiner uses the bus:device ID returned by DeviceLib; no cardX ordering.
dev="/sys/bus/pci/devices/0000:${bus,,}.0"
[[ -d "$dev" ]] || { echo "AMD GPU not found at PCI $bus" >&2; exit 1; }
[[ "$(<"$dev/vendor")" == "0x1002" ]] || { echo "PCI $bus is not an AMD GPU" >&2; exit 1; }
od="$dev/pp_od_clk_voltage"
perf="$dev/power_dpm_force_performance_level"

cap_path=""
cap_target=""
# Snapshots survive separate miner runs but not a host reboot.
state_dir="/run/rainbowminer-amd-oc"
state="$state_dir/${bus,,}.state"
# Serialize requests per PCI GPU, avoiding concurrent OC apply/reset races.
# Dry runs never require write access to the state directory.
if ((!dry_run)); then
    [[ ! -L "$state_dir" ]] || { echo "Refusing symlinked AMD OC state directory" >&2; exit 1; }
    command -v flock >/dev/null 2>&1 || { echo "AMD OC requires flock (util-linux)" >&2; exit 1; }
    mkdir -p -m 0700 "$state_dir"
    exec {oc_lock_fd}>"$state.lock"
    flock -x "$oc_lock_fd"
fi

write_od_command() {
    printf '%s\n' "$1" > "$od"
}
get_current_max() {
    local kind=$1
    awk -v kind="$kind" '
        $0 == "OD_" kind ":" {found=1; next}
        found && /^1:/ {
            gsub(/[Mm][Hh][Zz]/, "", $2)
            print $2
            exit
        }' <<< "$od_text"
}
get_current_offset() {
    awk '/^OD_VDDGFX_OFFSET:/ {getline; gsub(/[Mm][Vv]/,"",$1); print $1; exit}' <<< "$od_text"
}
# Verify the driver accepted requested settings, not just successful writes.
# A failed readback leaves the baseline available for a retry/reset.
verify_readback() {
    local desired_core=$1 desired_mem=$2 desired_offset=$3
    local actual
    od_text=$(LC_ALL=C tr -d '\000' < "$od")
    if [[ -n "$desired_core" ]]; then
        actual=$(get_current_max SCLK)
        [[ "$actual" == "$desired_core" ]] || { echo "AMD core readback mismatch for PCI $bus: expected $desired_core, got $actual" >&2; return 1; }
    fi
    if [[ -n "$desired_mem" ]]; then
        actual=$(get_current_max MCLK)
        [[ "$actual" == "$desired_mem" ]] || { echo "AMD memory readback mismatch for PCI $bus: expected $desired_mem, got $actual" >&2; return 1; }
    fi
    if [[ -n "$desired_offset" ]]; then
        actual=$(get_current_offset)
        [[ "$actual" == "$desired_offset" ]] || { echo "AMD voltage-offset readback mismatch for PCI $bus: expected $desired_offset, got $actual" >&2; return 1; }
    fi
}
# Restore all RainbowMiner-managed controls to the pre-mining baseline.
# Never write an AMD PowerPlay table or invoke the driver-wide OD 'r' reset.
restore_baseline() {
    if [[ ! -f "$state" ]]; then
        echo "AMD OC reset PCI $bus: no saved baseline; nothing to restore"
        return 0
    fi
    [[ ! -L "$state" ]] || { echo "Refusing symlinked baseline" >&2; exit 1; }
    read -r saved_cap saved_core saved_mem saved_perf saved_clocks saved_offset saved_voltage saved_power < "$state"
    saved_voltage=${saved_voltage:-0}
    saved_power=${saved_power:-1} # legacy snapshots restored power
    [[ "$saved_cap" =~ ^[0-9]+$ && "$saved_core" =~ ^[0-9]+$ && "$saved_mem" =~ ^[0-9]+$ ]] || {
        echo "Invalid AMD OC baseline for PCI $bus" >&2; exit 1
    }
    [[ "$saved_clocks" =~ ^[01]$ && "$saved_voltage" =~ ^[01]$ && "$saved_power" =~ ^[01]$ ]] || { echo "Invalid AMD OC baseline flags for PCI $bus" >&2; exit 1; }
    if ((saved_voltage)); then
        [[ "$saved_offset" =~ ^-?[0-9]+$ ]] || { echo "Invalid AMD voltage baseline for PCI $bus" >&2; exit 1; }
    fi
    [[ "$saved_perf" =~ ^(auto|manual|high|low|profile_standard|profile_min_sclk|profile_min_mclk|profile_peak)$ ]] || {
        echo "Invalid AMD OC performance mode in baseline for PCI $bus" >&2; exit 1
    }
    cap_path=""
    for hwmon in "$dev"/hwmon/hwmon*; do
        if [[ -e "$hwmon/power1_cap" ]]; then cap_path="$hwmon/power1_cap"; break; fi
    done
    [[ -e "$od" && -e "$perf" ]] || {
        echo "AMD OC reset interfaces unavailable for PCI $bus; baseline kept" >&2; exit 1
    }
    if ((saved_power)) && [[ -z "$cap_path" ]]; then
        echo "AMD power cap unavailable for reset PCI $bus; preserving baseline" >&2; exit 1
    fi
    if ((dry_run)); then
        echo "DRY-RUN RESET PCI $bus: cap=${saved_cap}uW core=${saved_core}MHz mem=${saved_mem}MHz mode=$saved_perf"
        return 0
    fi
    [[ -w "$od" && -w "$perf" ]] && { ((!saved_power)) || [[ -w "$cap_path" ]]; } || {
        echo "AMD OC reset requires privileged access on PCI $bus; baseline kept" >&2; exit 1
    }
    if ((saved_clocks || saved_voltage)); then
        printf 'manual\n' > "$perf"
        if ((saved_clocks)); then
            write_od_command "s 1 $saved_core"
            write_od_command "m 1 $saved_mem"
        fi
        if ((saved_voltage)); then write_od_command "vo $saved_offset"; fi
        write_od_command "c"
    fi
    if ((saved_power)); then printf '%s\n' "$saved_cap" > "$cap_path"; fi
    if ((saved_clocks || saved_voltage)); then printf '%s\n' "$saved_perf" > "$perf"; fi
    if ((saved_clocks || saved_voltage)); then
        verify_readback "$(if ((saved_clocks)); then echo "$saved_core"; fi)" "$(if ((saved_clocks)); then echo "$saved_mem"; fi)" "$(if ((saved_voltage)); then echo "$saved_offset"; fi)"
        [[ "$(<"$perf")" == "$saved_perf" ]] || { echo "AMD performance-level restore mismatch for PCI $bus" >&2; exit 1; }
    fi
    if ((saved_power)); then
        [[ "$(<"$cap_path")" == "$saved_cap" ]] || { echo "AMD power-cap restore mismatch for PCI $bus" >&2; exit 1; }
    fi
    rm -f -- "$state"
    echo "AMD OC reset PCI $bus: previous settings restored"
    return 0
}

if ((reset)); then
    restore_baseline
    exit 0
fi
if [[ -n "$power_percent" ]]; then
    for hwmon in "$dev"/hwmon/hwmon*; do
        if [[ -r "$hwmon/power1_cap_default" && -r "$hwmon/power1_cap_min" && -r "$hwmon/power1_cap_max" && -e "$hwmon/power1_cap" ]]; then
            cap_path="$hwmon/power1_cap"
            break
        fi
    done
    [[ -n "$cap_path" ]] || { echo "AMD power cap not available on PCI $bus" >&2; exit 1; }
    def=$(<"$hwmon/power1_cap_default")
    min=$(<"$hwmon/power1_cap_min")
    max=$(<"$hwmon/power1_cap_max")
    [[ "$def" =~ ^[0-9]+$ && "$min" =~ ^[0-9]+$ && "$max" =~ ^[0-9]+$ ]] || {
        echo "Invalid AMD power cap data on PCI $bus" >&2; exit 1
    }
    cap_target=$(( def * power_percent / 100 ))
    ((cap_target < min)) && cap_target=$min
    ((cap_target > max)) && cap_target=$max
fi

# Preflight all requested settings before any sysfs writes, to reduce partial applies.
clock_change=0
voltage_change=0
if [[ -n "$core_max" || -n "$mem_max" || -n "$voltage_offset" ]]; then
    [[ -r "$od" && -e "$perf" ]] || { echo "AMD OC interface unavailable on PCI $bus" >&2; exit 1; }
    od_text=$(LC_ALL=C tr -d '\000' < "$od")
    get_range() {
        local label=$1
        awk -v label="$label" '
            /^OD_RANGE:/ {in_range=1; next}
            in_range && $1 == label ":" {
                gsub(/[Mm][Hh][Zz]|[Mm][Vv]/,"",$2)
                gsub(/[Mm][Hh][Zz]|[Mm][Vv]/,"",$3)
                print $2, $3
                exit
            }' <<< "$od_text"
    }
    if [[ -n "$core_max" ]]; then
        read -r core_min core_limit < <(get_range SCLK) || {
            echo "Could not read core clock limits on PCI $bus" >&2; exit 1
        }
        [[ "$core_min" =~ ^[0-9]+$ && "$core_limit" =~ ^[0-9]+$ ]] || {
            echo "Could not read core clock limits on PCI $bus" >&2; exit 1
        }
        (( core_max >= core_min && core_max <= core_limit )) || {
            echo "Core maximum ${core_max}MHz outside ${core_min}-${core_limit}MHz on PCI $bus" >&2; exit 1
        }
        clock_change=1
    fi
    if [[ -n "$mem_max" ]]; then
        read -r mem_min mem_limit < <(get_range MCLK) || {
            echo "Could not read memory clock limits on PCI $bus" >&2; exit 1
        }
        [[ "$mem_min" =~ ^[0-9]+$ && "$mem_limit" =~ ^[0-9]+$ ]] || {
            echo "Could not read memory clock limits on PCI $bus" >&2; exit 1
        }
        (( mem_max >= mem_min && mem_max <= mem_limit )) || {
            echo "Memory maximum ${mem_max}MHz outside ${mem_min}-${mem_limit}MHz on PCI $bus" >&2; exit 1
        }
        clock_change=1
    fi
    if [[ -n "$voltage_offset" ]]; then
        [[ "$od_text" == *"OD_VDDGFX_OFFSET:"* ]] || { echo "AMD voltage offset not supported by this GPU" >&2; exit 1; }
        if ! read -r offset_min offset_max < <(get_range VDDGFX_OFFSET); then
            echo "AMD voltage-offset range unavailable for PCI $bus; cannot safely set voltage" >&2
            exit 1
        fi
        [[ "$offset_min" =~ ^-?[0-9]+$ && "$offset_max" =~ ^-?[0-9]+$ ]] || {
            echo "No supported AMD voltage offset range on PCI $bus" >&2; exit 1
        }
        (( voltage_offset >= offset_min && voltage_offset <= offset_max )) || {
            echo "Voltage offset ${voltage_offset}mV outside ${offset_min}..${offset_max}mV on PCI $bus" >&2; exit 1
        }
        voltage_change=1
    fi
fi

if ((dry_run)); then
    echo "DRY-RUN PCI $bus: replace-profile=$replace_profile power-cap=${cap_target:-unchanged}uW core-max=${core_max:-unchanged}MHz mem-max=${mem_max:-unchanged}MHz voltage-offset=${voltage_offset:-unchanged}mV"
    exit 0
fi

# The privileged OCDaemon invokes this helper. Fail before changing any settings
# if any required sysfs file is inaccessible to that process.
if [[ -n "$cap_path" && ! -w "$cap_path" ]]; then
    echo "No permission to set AMD power cap on PCI $bus" >&2; exit 1
fi
if ((clock_change || voltage_change)) && [[ ! -w "$od" || ! -w "$perf" ]]; then
    echo "No permission to set AMD clocks on PCI $bus" >&2; exit 1
fi

# Switching between algorithms replaces the whole per-GPU profile.
# Restore first (under the existing PCI flock) so omitted/zero/"*" values
# never inherit the previous algorithm's core/memory/voltage/power setting.
# Requested settings have already passed range/permissions preflight above.
if ((replace_profile)); then
    restore_baseline
fi

# Capture a per-GPU baseline before any live writes. Repeated applications retain
# the initial baseline until the miner stop/reset path restores it.
if [[ -n "$cap_target" || "$clock_change" -eq 1 || "$voltage_change" -eq 1 ]]; then
    if [[ ! -e "$state" ]]; then
        [[ -r "$od" && -r "$perf" ]] || { echo "Cannot capture AMD baseline for PCI $bus" >&2; exit 1; }
        od_text=$(LC_ALL=C tr -d '\000' < "$od")
        original_core=$(get_current_max SCLK)
        original_mem=$(get_current_max MCLK)
        original_offset=$(get_current_offset)
        original_perf=$(<"$perf")
        original_cap=""
        for hwmon in "$dev"/hwmon/hwmon*; do
            if [[ -r "$hwmon/power1_cap" ]]; then original_cap=$(<"$hwmon/power1_cap"); break; fi
        done
        [[ "$original_core" =~ ^[0-9]+$ && "$original_mem" =~ ^[0-9]+$ ]] || {
            echo "Could not capture AMD clocks for PCI $bus" >&2; exit 1
        }
        if [[ -z "$original_cap" ]]; then
            [[ -z "$cap_target" ]] || { echo "No power baseline for PCI $bus" >&2; exit 1; }
            original_cap=0
        fi
        if ((voltage_change)) && [[ ! "$original_offset" =~ ^-?[0-9]+$ ]]; then
            echo "Cannot capture voltage-offset baseline for PCI $bus" >&2; exit 1
        fi
        [[ "$original_offset" =~ ^-?[0-9]+$ ]] || original_offset=0
        umask 077
        mkdir -p -m 0700 "$state_dir"
        [[ ! -L "$state_dir" ]] || { echo "Refusing symlinked state directory" >&2; exit 1; }
        want_power=0
        [[ -n "$cap_target" ]] && want_power=1
        printf '%s %s %s %s %s %s %s %s\n' "$original_cap" "$original_core" "$original_mem" "$original_perf" "$clock_change" "$original_offset" "$voltage_change" "$want_power" > "$state.tmp.$$"
        mv -n -- "$state.tmp.$$" "$state"
    else
        # Preserve the original baseline when promoting flags during profile changes.
        read -r original_cap original_core original_mem original_perf snapshot_clocks original_offset snapshot_voltage snapshot_power < "$state"
        snapshot_voltage=${snapshot_voltage:-0}
        snapshot_power=${snapshot_power:-1}
        [[ "$original_cap" =~ ^[0-9]+$ && "$original_core" =~ ^[0-9]+$ && "$original_mem" =~ ^[0-9]+$ && "$snapshot_clocks" =~ ^[01]$ && "$snapshot_voltage" =~ ^[01]$ && "$snapshot_power" =~ ^[01]$ ]] || {
            echo "Invalid pre-existing AMD OC snapshot for PCI $bus" >&2; exit 1
        }
        if ((voltage_change && !snapshot_voltage)); then
            od_text=$(LC_ALL=C tr -d '\000' < "$od")
            original_offset=$(get_current_offset)
            [[ "$original_offset" =~ ^-?[0-9]+$ ]] || {
                echo "Cannot capture previous voltage offset on PCI $bus" >&2; exit 1
            }
        fi
        [[ "$original_offset" =~ ^-?[0-9]+$ ]] || original_offset=0
        want_power=0
        [[ -n "$cap_target" ]] && want_power=1
        if ((want_power && !snapshot_power && original_cap == 0)); then
            original_cap=$(<"$cap_path")
            [[ "$original_cap" =~ ^[0-9]+$ && "$original_cap" -gt 0 ]] || { echo "Cannot capture new power baseline on PCI $bus" >&2; exit 1; }
        fi
        if (( (clock_change && !snapshot_clocks) || (voltage_change && !snapshot_voltage) || (want_power && !snapshot_power) )); then
            printf '%s %s %s %s %s %s %s %s\n' "$original_cap" "$original_core" "$original_mem" "$original_perf" "$((snapshot_clocks || clock_change))" "$original_offset" "$((snapshot_voltage || voltage_change))" "$((snapshot_power || want_power))" > "$state.tmp.$$"
            mv -f -- "$state.tmp.$$" "$state"
        fi
    fi
fi

# Power/clock changes happen live. The full reset ('r') and pp_table writes are
# intentionally excluded: they caused SMU instability during RDNA2 testing.
if [[ -n "$cap_target" ]]; then printf '%s\n' "$cap_target" > "$cap_path"; fi
if ((clock_change || voltage_change)); then
    printf 'manual\n' > "$perf"
    if [[ -n "$core_max" ]]; then write_od_command "s 1 $core_max"; fi
    if [[ -n "$mem_max" ]]; then write_od_command "m 1 $mem_max"; fi
    if [[ -n "$voltage_offset" ]]; then write_od_command "vo $voltage_offset"; fi
    write_od_command "c"
    verify_readback "$core_max" "$mem_max" "$voltage_offset"
fi
if [[ -n "$cap_target" ]]; then
    [[ "$(<"$cap_path")" == "$cap_target" ]] || { echo "AMD power-cap readback mismatch for PCI $bus" >&2; exit 1; }
fi
