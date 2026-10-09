#!/usr/bin/env bash
# RainbowMiner - AMD GPU overclocking on Linux through the amdgpu OverDrive sysfs interface
#
# Runs as root through the ocdaemon, one call per GPU, the GPU is addressed by its PCI bus id:
#
#   bash amd_oc.sh --bus 03:00 [--core-max MHz] [--core-offset MHz] [--mem-max MHz]
#                              [--voltage-offset mV] [--power-percent 20..200] [--dry-run]
#   bash amd_oc.sh --bus 03:00 --reset
#   bash amd_oc.sh --bus 03:00 --query
#
# The first change records the GPU's current clocks, voltage offset, power cap and performance
# level in a state file. A later call that leaves a field out puts that field back to the
# recorded value, so a profile switch never inherits the previous profile, and --reset restores
# everything and removes the state file.
#
# What the driver prints in pp_od_clk_voltage differs by generation, so the script reads the
# layout instead of guessing it from the model:
#   Vega20, RDNA1 (Navi1x)  OD_SCLK 0:/1: min/max, OD_MCLK 1: max only, OD_VDDC_CURVE (not used)
#   RDNA2, RDNA3            OD_SCLK 0:/1:, OD_MCLK 0:/1:, OD_VDDGFX_OFFSET (RDNA2 prints no range for it)
#   RDNA4                   OD_SCLK_OFFSET (a core clock offset instead of a maximum), OD_MCLK 0:/1:, OD_VDDGFX_OFFSET
#   Polaris, Vega10         per-state tables with voltages: the clocks are left alone, only the power cap is set
# OverDrive must be enabled in the driver (kernel parameter amdgpu.ppfeaturemask=0xffffffff),
# otherwise pp_od_clk_voltage is missing and only the power cap can be changed.
#
# Every refused or unsupported setting is reported in one line and leaves the GPU as it was.

set -u -o pipefail
export LC_ALL=C

sysfs_root=${RBM_AMD_SYSFS:-/sys/bus/pci/devices}
state_dir=${RBM_AMD_STATE_DIR:-/run/rainbowminer/amd-oc}
# software limits for the voltage offset when the driver prints no VDDGFX_OFFSET range (RDNA2)
vo_fallback_min=-200
vo_fallback_max=0

bus="" core_max="" core_offset="" mem_max="" voltage_offset="" power_percent=""
do_reset=0 do_query=0 dry_run=0

usage() {
    echo "usage: $0 --bus BB:DD [--core-max MHz] [--core-offset MHz] [--mem-max MHz] [--voltage-offset mV] [--power-percent 20..200] [--reset] [--query] [--dry-run]" >&2
}
fail() { echo "ERROR: AMD OC $bus: $*" >&2; exit 1; }
err()  { echo "ERROR: AMD OC $bus: $*" >&2; rc=1; }
note() { echo "AMD OC $bus: $*"; }

while (($#)); do
    case "$1" in
        --bus|--core-max|--core-offset|--mem-max|--voltage-offset|--power-percent)
            (($# >= 2)) || { usage; exit 2; }
            case "$1" in
                --bus)            bus=$2 ;;
                --core-max)       core_max=$2 ;;
                --core-offset)    core_offset=$2 ;;
                --mem-max)        mem_max=$2 ;;
                --voltage-offset) voltage_offset=$2 ;;
                --power-percent)  power_percent=$2 ;;
            esac
            shift 2 ;;
        --reset)   do_reset=1; shift ;;
        --query)   do_query=1; shift ;;
        --dry-run) dry_run=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

[[ "$bus" =~ ^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}$ ]] || { echo "AMD OC: invalid PCI bus id '$bus'" >&2; exit 2; }
bus=${bus,,}
[[ -z "$core_max"       || "$core_max"       =~ ^[0-9]+$   ]] || fail "invalid core clock '$core_max'"
[[ -z "$core_offset"    || "$core_offset"    =~ ^-?[0-9]+$ ]] || fail "invalid core clock offset '$core_offset'"
[[ -z "$mem_max"        || "$mem_max"        =~ ^[0-9]+$   ]] || fail "invalid memory clock '$mem_max'"
[[ -z "$voltage_offset" || "$voltage_offset" =~ ^-?[0-9]+$ ]] || fail "invalid voltage offset '$voltage_offset'"
[[ -z "$power_percent"  || "$power_percent"  =~ ^[0-9]+$   ]] || fail "invalid power percent '$power_percent'"
if [[ -n "$power_percent" ]] && ((10#$power_percent < 20 || 10#$power_percent > 200)); then fail "the power percent must be 20..200"; fi
[[ -z "$core_max" || -z "$core_offset" ]] || fail "--core-max and --core-offset cannot be combined"
if ((do_reset)) && [[ -n "$core_max$core_offset$mem_max$voltage_offset$power_percent" ]]; then fail "--reset cannot be combined with settings"; fi

# ---- locate the GPU ---------------------------------------------------------------------------
dev=""
for d in "$sysfs_root"/????:"$bus".0; do
    if [[ -d "$d" ]]; then dev=$d; break; fi
done
[[ -n "$dev" ]] || fail "no PCI device at $bus"
[[ "$(cat "$dev/vendor" 2>/dev/null)" == "0x1002" ]] || fail "the device at $bus is not an AMD GPU"
od="$dev/pp_od_clk_voltage"
perf="$dev/power_dpm_force_performance_level"
hwmon=""
for h in "$dev"/hwmon/hwmon*; do
    if [[ -e "$h/power1_cap" ]]; then hwmon=$h; break; fi
done

sysfs_read() { cat "$1" 2>/dev/null; }
sysfs_write() {
    # RBM_AMD_WRITE_HOOK lets a test harness stand in for the driver
    if [[ -n "${RBM_AMD_WRITE_HOOK:-}" ]]; then "$RBM_AMD_WRITE_HOOK" "$1" "$2"; return $?; fi
    printf '%s\n' "$2" > "$1" 2>/dev/null
}

# ---- OverDrive table parsing ------------------------------------------------------------------
od_text=""
read_od() { if [[ -r "$od" ]]; then od_text=$(tr -d '\000' < "$od" 2>/dev/null); else od_text=""; fi; }
od_has()  { grep -q "^$1:" <<< "$od_text"; }
od_line() { # section, index label -> value without unit, e.g. od_line OD_SCLK 1
    awk -v sec="$1:" -v idx="$2:" '
        /^OD_[A-Z_]+:/ {insec = ($1 == sec); next}
        insec && $1 == idx {v = $2; sub(/[A-Za-z]+$/, "", v); print v; exit}' <<< "$od_text"
}
od_value() { # section with a single value line, e.g. od_value OD_VDDGFX_OFFSET
    awk -v sec="$1:" '
        /^OD_[A-Z_]+:/ {insec = ($1 == sec); next}
        insec {v = $1; sub(/[A-Za-z]+$/, "", v); print v; exit}' <<< "$od_text"
}
od_range() { # label inside OD_RANGE -> "min max" without units
    awk -v lab="$1:" '
        /^OD_[A-Z_]+:/ {inrange = ($1 == "OD_RANGE:"); next}
        inrange && $1 == lab {a = $2; b = $3; sub(/[A-Za-z]+$/, "", a); sub(/[A-Za-z]+$/, "", b); print a, b; exit}' <<< "$od_text"
}
od_has_mv() { awk -v sec="$1:" '/^OD_[A-Z_]+:/ {insec = ($1 == sec); next} insec && /mV/ {f = 1} END {exit !f}' <<< "$od_text"; }

core_mode="none"; mem_mode="none"; vo_mode="none"
detect_layout() {
    read_od
    core_mode="none"; mem_mode="none"; vo_mode="none"
    if od_has OD_SCLK_OFFSET; then
        core_mode="offset"
    elif od_has OD_SCLK; then
        if od_has_mv OD_SCLK; then core_mode="legacy"; elif [[ -n "$(od_line OD_SCLK 1)" ]]; then core_mode="max"; fi
    fi
    if od_has OD_MCLK; then
        if od_has_mv OD_MCLK; then mem_mode="legacy"; elif [[ -n "$(od_line OD_MCLK 1)" ]]; then mem_mode="max"; fi
    fi
    if od_has OD_VDDGFX_OFFSET; then vo_mode="offset"; fi
}
cur_core() { case "$core_mode" in max) od_line OD_SCLK 1 ;; offset) od_value OD_SCLK_OFFSET ;; esac; }
cur_mem()  { if [[ "$mem_mode" == "max" ]]; then od_line OD_MCLK 1; fi; }
cur_vo()   { if [[ "$vo_mode" == "offset" ]]; then od_value OD_VDDGFX_OFFSET; fi; }
cur_cap()  { if [[ -n "$hwmon" ]]; then sysfs_read "$hwmon/power1_cap"; fi; }
cur_perf() { sysfs_read "$perf"; }
od_missing_hint() { echo "OverDrive is not enabled, boot with amdgpu.ppfeaturemask=0xffffffff"; }

state="$state_dir/$bus.state"

if ((do_query)); then
    detect_layout
    echo "device:  $dev"
    if [[ -e "$od" ]]; then echo "layout:  core=$core_mode mem=$mem_mode voltage=$vo_mode"; else echo "layout:  no pp_od_clk_voltage ($(od_missing_hint))"; fi
    echo "perf:    $(cur_perf)"
    echo "core:    $(cur_core) range: $(od_range SCLK)$(od_range SCLK_OFFSET)"
    echo "mem:     $(cur_mem) range: $(od_range MCLK)"
    echo "voltage: $(cur_vo) range: $(od_range VDDGFX_OFFSET)"
    if [[ -n "$hwmon" ]]; then
        echo "power:   cap=$(cur_cap) default=$(sysfs_read "$hwmon/power1_cap_default") min=$(sysfs_read "$hwmon/power1_cap_min") max=$(sysfs_read "$hwmon/power1_cap_max") (uW)"
    else
        echo "power:   no power cap in hwmon"
    fi
    if [[ -f "$state" ]]; then echo "state:   $(tr '\n' ' ' < "$state")"; else echo "state:   none"; fi
    exit 0
fi

# ---- per-GPU lock and state -------------------------------------------------------------------
if ((!dry_run)); then
    mkdir -p -m 0700 "$state_dir" 2>/dev/null || fail "cannot create $state_dir"
    [[ ! -L "$state_dir" ]] || fail "$state_dir is a symlink"
    if command -v flock >/dev/null 2>&1; then
        exec {lock_fd}>"$state_dir/$bus.lock" || fail "cannot open the lock file"
        flock -w 30 "$lock_fd" || fail "another OC call for this GPU is still running"
    fi
fi

declare -A base=() managed=()
load_state() {
    [[ -f "$state" && ! -L "$state" ]] || return 1
    local k v
    while IFS='=' read -r k v; do
        case "$k" in
            perf) if [[ "$v" =~ ^[a-z_]+$ ]]; then base[perf]=$v; fi ;;
            core|mem|vo|cap) if [[ "$v" =~ ^-?[0-9]+$ ]]; then base[$k]=$v; fi ;;
            core_managed|mem_managed|vo_managed|cap_managed) if [[ "$v" =~ ^[01]$ ]]; then managed[${k%_managed}]=$v; fi ;;
        esac
    done < "$state"
    return 0
}
save_state() {
    local tmp="$state.tmp.$$" k
    {
        echo "perf=${base[perf]:-}"
        for k in core mem vo cap; do
            echo "$k=${base[$k]:-}"
            echo "${k}_managed=${managed[$k]:-0}"
        done
    } > "$tmp" && mv -f -- "$tmp" "$state"
}
capture_baseline() {
    base[perf]=$(cur_perf); base[core]=$(cur_core); base[mem]=$(cur_mem); base[vo]=$(cur_vo); base[cap]=$(cur_cap)
    managed=([core]=0 [mem]=0 [vo]=0 [cap]=0)
}

detect_layout
if ! load_state; then
    if ((do_reset)); then note "nothing to restore"; exit 0; fi
    capture_baseline
fi
for k in core mem vo cap; do managed[$k]=${managed[$k]:-0}; done

# ---- work out the target value of every field --------------------------------------------------
# a requested field gets the requested value, a field that is left out goes back to the baseline
# if RainbowMiner had changed it before, anything else is left alone
want_core="" want_mem="" want_vo="" want_cap=""
check_range() { # value, OD_RANGE label, fallback min, fallback max, description
    local v=$1 r lo hi
    r=$(od_range "$2")
    if [[ -n "$r" ]]; then read -r lo hi <<< "$r"; else lo=$3; hi=$4; fi
    [[ -n "$lo" && -n "$hi" ]] || return 0
    (( v >= lo && v <= hi )) || fail "$5 $v is outside the allowed range $lo..$hi"
}
if ((do_reset)); then
    if ((managed[core])); then want_core=${base[core]}; fi
    if ((managed[mem]));  then want_mem=${base[mem]};   fi
    if ((managed[vo]));   then want_vo=${base[vo]};     fi
    if ((managed[cap]));  then want_cap=${base[cap]};   fi
    managed=([core]=0 [mem]=0 [vo]=0 [cap]=0)
else
    if [[ -n "$core_max" ]]; then
        case "$core_mode" in
            max)    check_range "$core_max" SCLK "" "" "the core clock"; want_core=$core_max; managed[core]=1 ;;
            offset) note "LockCoreClock is not supported on this GPU, it takes a core clock offset (CoreClockBoost)" ;;
            legacy) note "the core clock is not supported on this GPU (per-state OverDrive table)" ;;
            *)      note "the core clock is not supported: $(od_missing_hint)" ;;
        esac
    elif [[ -n "$core_offset" ]]; then
        case "$core_mode" in
            offset) check_range "$core_offset" SCLK_OFFSET "" "" "the core clock offset"; want_core=$core_offset; managed[core]=1 ;;
            max)    note "CoreClockBoost is not supported on this GPU, it takes a core clock maximum (LockCoreClock)" ;;
            legacy) note "the core clock is not supported on this GPU (per-state OverDrive table)" ;;
            *)      note "the core clock is not supported: $(od_missing_hint)" ;;
        esac
    elif ((managed[core])); then
        want_core=${base[core]}; managed[core]=0
    fi
    if [[ -n "$mem_max" ]]; then
        case "$mem_mode" in
            max)    check_range "$mem_max" MCLK "" "" "the memory clock"; want_mem=$mem_max; managed[mem]=1 ;;
            legacy) note "the memory clock is not supported on this GPU (per-state OverDrive table)" ;;
            *)      note "the memory clock is not supported: $(od_missing_hint)" ;;
        esac
    elif ((managed[mem])); then
        want_mem=${base[mem]}; managed[mem]=0
    fi
    if [[ -n "$voltage_offset" ]]; then
        case "$vo_mode" in
            offset) check_range "$voltage_offset" VDDGFX_OFFSET "$vo_fallback_min" "$vo_fallback_max" "the voltage offset"; want_vo=$voltage_offset; managed[vo]=1 ;;
            *)      if [[ -e "$od" ]]; then note "the voltage offset is not supported on this GPU"; else note "the voltage offset is not supported: $(od_missing_hint)"; fi ;;
        esac
    elif ((managed[vo])); then
        want_vo=${base[vo]}; managed[vo]=0
    fi
    if [[ -n "$power_percent" ]]; then
        if [[ -z "$hwmon" ]]; then
            note "the power limit is not supported on this GPU (no power cap in hwmon)"
        else
            def=$(sysfs_read "$hwmon/power1_cap_default"); mn=$(sysfs_read "$hwmon/power1_cap_min"); mx=$(sysfs_read "$hwmon/power1_cap_max")
            [[ "$def" =~ ^[0-9]+$ && "$def" -gt 0 ]] || def=${base[cap]:-}
            [[ "$def" =~ ^[0-9]+$ && "$def" -gt 0 ]] || fail "cannot read the default power cap"
            want_cap=$(( def * 10#$power_percent / 100 ))
            if [[ "$mn" =~ ^[0-9]+$ ]] && (( want_cap < mn )); then want_cap=$mn; fi
            if [[ "$mx" =~ ^[0-9]+$ ]] && (( want_cap > mx )); then want_cap=$mx; fi
            managed[cap]=1
        fi
    elif ((managed[cap])); then
        want_cap=${base[cap]}; managed[cap]=0
    fi
fi

cur_core_v=$(cur_core); cur_mem_v=$(cur_mem); cur_vo_v=$(cur_vo); cur_cap_v=$(cur_cap)
od_cmds=()
if [[ -n "$want_core" && "$want_core" != "$cur_core_v" ]]; then
    if [[ "$core_mode" == "offset" ]]; then od_cmds+=("s $want_core"); else od_cmds+=("s 1 $want_core"); fi
fi
if [[ -n "$want_mem" && "$want_mem" != "$cur_mem_v" ]]; then od_cmds+=("m 1 $want_mem"); fi
if [[ -n "$want_vo"  && "$want_vo"  != "$cur_vo_v"  ]]; then od_cmds+=("vo $want_vo"); fi
cap_change=0
if [[ -n "$want_cap" && "$want_cap" != "$cur_cap_v" ]]; then cap_change=1; fi
managed_any=$(( managed[core] || managed[mem] || managed[vo] || managed[cap] ))

summary="core=${want_core:-$cur_core_v} mem=${want_mem:-$cur_mem_v} voltage=${want_vo:-$cur_vo_v}mV cap=$(( ${want_cap:-${cur_cap_v:-0}} / 1000000 ))W"
if ((dry_run)); then
    note "dry run: $summary od=[${od_cmds[*]:-}] cap_change=$cap_change managed=$managed_any"
    exit 0
fi

# the baseline is on disk before the first write, so that a reset always finds it
save_state || fail "cannot write the state file"

restage() { # put the current values back into the staged table, so nothing half-done is committed later
    local c
    for c in "${od_cmds[@]}"; do
        case "$c" in
            "s "*)  if [[ "$core_mode" == "offset" ]]; then sysfs_write "$od" "s $cur_core_v"; else sysfs_write "$od" "s 1 $cur_core_v"; fi ;;
            "m "*)  sysfs_write "$od" "m 1 $cur_mem_v" ;;
            "vo "*) sysfs_write "$od" "vo $cur_vo_v" ;;
        esac
    done >/dev/null 2>&1
}

rc=0
if ((${#od_cmds[@]})); then
    [[ -w "$od" && -w "$perf" ]] || fail "no write access to the OverDrive interface"
    if [[ "$(cur_perf)" != "manual" ]]; then
        sysfs_write "$perf" manual || fail "cannot set the performance level to manual"
    fi
    for c in "${od_cmds[@]}"; do
        if ! sysfs_write "$od" "$c"; then restage; fail "the driver refused '$c' ($summary)"; fi
    done
    if ! sysfs_write "$od" c; then restage; fail "the driver refused the commit ($summary)"; fi
    read_od
    if [[ -n "$want_core" && "$(cur_core)" != "$want_core" ]]; then err "core clock readback $(cur_core) differs from $want_core"; fi
    if [[ -n "$want_mem"  && "$(cur_mem)"  != "$want_mem"  ]]; then err "memory clock readback $(cur_mem) differs from $want_mem"; fi
    if [[ -n "$want_vo"   && "$(cur_vo)"   != "$want_vo"   ]]; then err "voltage offset readback $(cur_vo) differs from $want_vo"; fi
fi
if ((cap_change)); then
    [[ -w "$hwmon/power1_cap" ]] || fail "no write access to the power cap"
    sysfs_write "$hwmon/power1_cap" "$want_cap" || fail "the driver refused the power cap $want_cap"
    if [[ "$(cur_cap)" != "$want_cap" ]]; then err "power cap readback $(cur_cap) differs from $want_cap"; fi
fi

if ((managed_any)); then
    save_state || fail "cannot write the state file"
    note "applied: $summary"
else
    if [[ -n "${base[perf]:-}" && "$(cur_perf)" != "${base[perf]}" ]]; then
        sysfs_write "$perf" "${base[perf]}" || note "could not restore the performance level ${base[perf]}"
    fi
    rm -f -- "$state"
    note "restored: $summary perf=${base[perf]:-}"
fi
exit $rc
