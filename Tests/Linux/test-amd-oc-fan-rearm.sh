#!/usr/bin/env bash
# Verify AMD PMFW Zero RPM state preservation before overclock commits.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HELPER="$ROOT/IncludesLinux/bash/amd_oc.sh"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
SYS="$TMP/sys/0000:03:00.0"
FAN="$SYS/gpu_od/fan_ctrl/fan_zero_rpm_enable"
OD="$SYS/pp_od_clk_voltage"
PERF="$SYS/power_dpm_force_performance_level"
mkdir -p "$(dirname "$FAN")"
echo 0x1002 >"$SYS/vendor"
cat > "$TMP/hook.sh" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
path=$1 value=$2
printf '%s|%s\n' "$(basename "$path")" "$value" >> "$RBM_TEST_LOG"
if [[ "$RBM_TEST_FAIL_FAN" == 1 && "$path" == */fan_zero_rpm_enable ]];then exit 12;fi
if [[ "$path" == */pp_od_clk_voltage && "$value" == "s 1 2600" ]];then
    sed -i 's/1: 2895Mhz/1: 2600Mhz/' "$path"
fi
HOOK
chmod 700 "$TMP/hook.sh"
reset_case() {
    rm -rf "$TMP/state"
    : > "$TMP/writes.log"
    cat >"$OD" <<'OD'
OD_SCLK:
0: 255Mhz
1: 2895Mhz
OD_MCLK:
0: 700MHz
1: 1125MHz
OD_VDDGFX_OFFSET:
0mV
OD_RANGE:
SCLK: 200Mhz 3000Mhz
MCLK: 500Mhz 1600Mhz
VDDGFX_OFFSET: -200mv 0mv
OD
    echo manual > "$PERF"
    mkdir -p "$(dirname "$FAN")"
    printf 'FAN_ZERO_RPM_ENABLE:\n0\nOD_RANGE:\nZERO_RPM_ENABLE: 0 1\n' > "$FAN"
}
run_helper() {
    RBM_AMD_SYSFS="$TMP/sys" RBM_AMD_STATE_DIR="$TMP/state" \
      RBM_AMD_WRITE_HOOK="$TMP/hook.sh" RBM_TEST_LOG="$TMP/writes.log" \
      RBM_TEST_FAIL_FAN="$(printenv RBM_TEST_FAIL_FAN || echo 0)" \
      bash "$HELPER" --bus 03:00 --core-max 2600 "$@"
}
assert_writes() {
    local expected=$1 actual
    actual=$(cat "$TMP/writes.log")
    if [[ "$actual" != "$expected" ]];then
        printf 'Expected writes:\n%s\nActual writes:\n%s\n' "$expected" "$actual" >&2
        exit 1
    fi
}
reset_case
run_helper >/dev/null
assert_writes $'fan_zero_rpm_enable|0\nfan_zero_rpm_enable|c\npp_od_clk_voltage|s 1 2600\npp_od_clk_voltage|c'
echo 'PASS: disabled Zero RPM rearmed before OC'

reset_case
printf 'FAN_ZERO_RPM_ENABLE:\n1\nOD_RANGE:\nZERO_RPM_ENABLE: 0 1\n' > "$FAN"
run_helper >/dev/null
assert_writes $'pp_od_clk_voltage|s 1 2600\npp_od_clk_voltage|c'
echo 'PASS: enabled Zero RPM left untouched'

reset_case
rm "$FAN"
run_helper >/dev/null
assert_writes $'pp_od_clk_voltage|s 1 2600\npp_od_clk_voltage|c'
echo 'PASS: no PMFW fan-control sysfs is unchanged'

reset_case
RBM_AMD_FAN_REARM=off run_helper >/dev/null
assert_writes $'pp_od_clk_voltage|s 1 2600\npp_od_clk_voltage|c'
echo 'PASS: opt-out disables rearm'

reset_case
run_helper --dry-run >/dev/null
[[ ! -s "$TMP/writes.log" ]]
echo 'PASS: dry-run has no writes'

reset_case
if RBM_TEST_FAIL_FAN=1 run_helper > "$TMP/failed.log" 2>&1;then
    echo 'FAIL: allowed clock commit after failed PMFW rearm' >&2;exit 1
fi
assert_writes 'fan_zero_rpm_enable|0'
echo 'PASS: PMFW rearm failure aborts before clock commit'
