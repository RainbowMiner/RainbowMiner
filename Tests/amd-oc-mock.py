#!/usr/bin/env python3
"""Mock AMDGPU sysfs integration tests for the native Linux OC helper.

No hardware writes or elevated permissions. Supports three independent fake GPUs,
with an emulated OD 'commit' interface to verify actual readback and restoration.
Run: python3 Tests/amd-oc-mock.py
"""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "IncludesLinux/bash/amd-oc.sh").read_text()

FAKE_OD_WRITER = r'''write_od_command() {
    if [[ -z "${mock_core:-}" ]]; then
        mock_core=$(awk '/^OD_SCLK:/{getline;getline;gsub(/[Mm][Hh][Zz]/,"",$2);print $2;exit}' "$od")
        mock_mem=$(awk '/^OD_MCLK:/{getline;getline;gsub(/[Mm][Hh][Zz]/,"",$2);print $2;exit}' "$od")
        mock_offset=$(awk '/^OD_VDDGFX_OFFSET:/{getline;gsub(/[Mm][Vv]/,"",$1);print $1;exit}' "$od")
    fi
    case "$1" in
        "s 1 "*) mock_core=$(echo "$1" | cut -d' ' -f3) ;;
        "m 1 "*) mock_mem=$(echo "$1" | cut -d' ' -f3) ;;
        "vo "*) mock_offset=$(echo "$1" | cut -d' ' -f2) ;;
        "c")
            if [[ "$MOCK_REJECT" != "1" ]]; then
                mock_ranges=$(sed -n '/^OD_RANGE:/,$p' "$od")
                printf 'OD_SCLK:\n0: 255Mhz\n1: %sMhz\nOD_MCLK:\n0: 97Mhz\n1: %sMHz\nOD_VDDGFX_OFFSET:\n%smV\n%s\n' "$mock_core" "$mock_mem" "$mock_offset" "$mock_ranges" > "$od"
            fi ;;
        *) echo "unexpected OD command: $1" >&2; return 3 ;;
    esac
}'''

orig_func = 'write_od_command() {\n    printf \'%s\\n\' "$1" > "$od"\n}'
assert SOURCE.count(orig_func) == 1, "OC function changed: update test mock"
assert SOURCE.count('state_dir="/run/rainbowminer-amd-oc"') == 1
old_dev = 'dev="/sys/bus/pci/devices/0000:' + '$' + '{bus,,}.0"'
assert SOURCE.count(old_dev) == 1

def make_gpu(base, bus, core, mem, offset=False, power=True, device_id="0x73ef"):
    dev = base / ("0000:" + bus + ".0")
    h = dev / "hwmon" / "hwmon0"
    h.mkdir(parents=True)
    (dev / "vendor").write_text("0x1002\n")
    (dev / "device").write_text(device_id + "\n")
    (dev / "power_dpm_force_performance_level").write_text("auto\n")
    v_range = "VDDGFX_OFFSET: -500mv 0mv\n" if offset else ""
    initial = (
        f"OD_SCLK:\n0: 255Mhz\n1: {core}Mhz\n"
        f"OD_MCLK:\n0: 97Mhz\n1: {mem}MHz\n"
        "OD_VDDGFX_OFFSET:\n0mV\n"
        "OD_RANGE:\nSCLK: 500Mhz 3150Mhz\nMCLK: 674Mhz 1200Mhz\n"
        + v_range
    )
    (dev / "pp_od_clk_voltage").write_text(initial)
    if power:
        for name, val in {
            "power1_cap": 130000000,
            "power1_cap_default": 130000000,
            "power1_cap_min": 110000000,
            "power1_cap_max": 170000000,
        }.items():
            (h / name).write_text(str(val) + "\n")
    return dev, initial

def state(base, bus):
    return base / "state" / (bus + ".state")

def limits(dev):
    s = (dev / "pp_od_clk_voltage").read_text()
    c = s.split("OD_SCLK:\n", 1)[1].split("OD_MCLK:", 1)[0]
    m = s.split("OD_MCLK:\n", 1)[1].split("OD_VDDGFX_OFFSET:", 1)[0]
    v = s.split("OD_VDDGFX_OFFSET:\n", 1)[1].split("\n", 1)[0]
    return (int(c.splitlines()[1].split()[1].replace("Mhz", "")),
            int(m.splitlines()[1].split()[1].replace("MHz", "")),
            int(v.replace("mV", "")))

with tempfile.TemporaryDirectory(prefix="amd-oc-tests-") as tmp:
    t = Path(tmp)
    fake = t / "pci"
    msi, old_msi = make_gpu(fake, "06:00", 2699, 1094)
    giga, old_giga = make_gpu(fake, "0a:00", 2694, 1094)
    rx7600, old_7600 = make_gpu(fake, "03:00", 2900, 1125, offset=True, device_id="0x7480")
    # Test missing power hwmon: clock-only changes should be possible.
    no_power, _ = make_gpu(fake, "0b:00", 2699, 1094, power=False)
    unknown, _ = make_gpu(fake, "0c:00", 2699, 1094, device_id="0xabcd")
    malformed, _ = make_gpu(fake, "0d:00", 2699, 1094)
    malformed_od = malformed / "pp_od_clk_voltage"
    malformed_od.write_text(malformed_od.read_text() +
                            "VDDGFX_OFFSET: invalid 0mv\n")

    candidate = SOURCE.replace(orig_func, FAKE_OD_WRITER)
    candidate = candidate.replace(old_dev, 'dev="' + str(fake) + '/0000:' + '$' + '{bus,,}.0"')
    candidate = candidate.replace('state_dir="/run/rainbowminer-amd-oc"', 'state_dir="' + str(t / "state") + '"')
    helper = t / "mock-amd-oc.sh"
    helper.write_text(candidate)

    def run(bus, *args, ok=True, reject=False):
        env = dict(os.environ, MOCK_REJECT="1" if reject else "0")
        proc = subprocess.run(
            ["bash", str(helper), "--bus", bus, *args], env=env,
            capture_output=True, text=True, timeout=8
        )
        if (proc.returncode == 0) != ok:
            raise AssertionError(f"OC test failed: bus={bus} args={args} "
                                 f"rc={proc.returncode}, out={proc.stdout!r}, err={proc.stderr!r}")
        return proc

    run("06:00", "--core-max", "1800", "--mem-max", "1150", "--dry-run")
    assert not state(t, "06:00").exists(), "Dry-run wrote persistent state"
    run("06:00", "--core-max", "1800", "--mem-max", "1150")
    run("0a:00", "--core-max", "1800", "--mem-max", "1150")
    assert limits(msi) == (1800, 1150, 0)
    assert limits(giga) == (1800, 1150, 0)
    assert (state(t, "06:00")).exists() and (state(t, "0a:00")).exists()
    print("PASS: two-card clocks applied; per-device baselines separate")

    run("06:00", "--reset")
    assert limits(msi) == (2699, 1094, 0)
    assert limits(giga) == (1800, 1150, 0)
    run("0a:00", "--reset")
    assert limits(giga) == (2694, 1094, 0)
    assert not state(t, "06:00").exists() and not state(t, "0a:00").exists()
    print("PASS: two-card independent reset; first reset does not disturb second")

    run("03:00", "--voltage-offset", "-250", "--core-max", "2200")
    assert limits(rx7600) == (2200, 1125, -250)
    run("03:00", "--core-max", "2300", "--voltage-offset", "-100")
    assert limits(rx7600) == (2300, 1125, -100)
    run("03:00", "--reset")
    assert limits(rx7600) == (2900, 1125, 0)
    assert (rx7600 / "power_dpm_force_performance_level").read_text().strip() == "auto"
    print("PASS: voltage/core apply, repeated profile switch, original baseline restoration")

    # Navi 23 advertises an offset value but not its allowed range on some
    # kernels. Real MSI and Gigabyte RX6650XT cards accepted -25mV through
    # LACT's sysfs backend; apply and restore that offset independently.
    for bus, card in (("06:00", msi), ("0a:00", giga)):
        run(bus, "--voltage-offset", "-25")
        assert limits(card)[2] == -25
        run(bus, "--reset")
        assert limits(card)[2] == 0
        assert not state(t, bus).exists()
    print("PASS: both Navi23 GPUs allow bounded voltage offset and restore")

    # Switching Navi23 from an undervolted profile to an omitted-voltage
    # profile must clear the voltage offset without touching other GPUs.
    run("06:00", "--replace-profile", "--core-max", "1800",
        "--voltage-offset", "-25")
    assert limits(msi) == (1800, 1094, -25)
    run("06:00", "--replace-profile", "--core-max", "2000")
    assert limits(msi) == (2000, 1094, 0)
    assert limits(giga) == (2694, 1094, 0)
    run("06:00", "--replace-profile")
    assert limits(msi) == (2699, 1094, 0)
    assert not state(t, "06:00").exists()
    print("PASS: Navi23 voltage switching clears prior undervolt")

    # Missing-range fallback is restricted to tested Navi 23 device ID,
    # with a conservative undervolt bound. Unknown GPUs must still fail.
    for bus, value in (("06:00", "-300"), ("06:00", "25"),
                       ("0c:00", "-25"), ("0d:00", "-25"),
                       ("03:00", "-700")):
        run(bus, "--voltage-offset", value, ok=False)
        assert not state(t, bus).exists()
    print("PASS: out-of-range and unknown-device offsets rejected preflight")

    # Missing advertised range is not permission to silently accept writes
    # ignored by the kernel. Readback must fail and preserve the baseline.
    run("06:00", "--voltage-offset", "-25", reject=True, ok=False)
    assert state(t, "06:00").exists() and limits(msi)[2] == 0
    run("06:00", "--reset")
    print("PASS: unadvertised offset requires real driver readback")

    run("06:00", "--core-max", "1800", reject=True, ok=False)
    assert state(t, "06:00").exists(), "readback failed but baseline was dropped"
    assert limits(msi) == (2699, 1094, 0)
    run("06:00", "--reset")
    assert not state(t, "06:00").exists()
    print("PASS: silently ignored OD commit detected, baseline remains recoverable")

    run("03:00", "--power-percent", "95", "--core-max", "2200")
    assert (rx7600 / "hwmon" / "hwmon0" / "power1_cap").read_text().strip() == "123500000"
    run("03:00", "--reset")
    assert (rx7600 / "hwmon" / "hwmon0" / "power1_cap").read_text().strip() == "130000000"
    print("PASS: power cap apply/readback/reset")

    # Historic five-field baseline remains restorable after voltage changes.
    state(t, "03:00").write_text("130000000 2900 1125 auto 1\n")
    run("03:00", "--voltage-offset", "-100")
    run("03:00", "--reset")
    assert limits(rx7600) == (2900, 1125, 0)
    print("PASS: legacy five-field state upgrade")

    # No power-cap interface should not prevent clock-only adjustment.
    run("0b:00", "--core-max", "1800")
    assert limits(no_power)[0] == 1800
    run("0b:00", "--reset")
    assert limits(no_power)[0] == 2699
    print("PASS: no-power-cap hardware can use native clock controls")

    # Later power changes must promote (but not overwrite) an earlier clock snapshot.
    run("06:00", "--core-max", "1800")
    assert state(t, "06:00").read_text().split()[-1] == "0"
    run("06:00", "--power-percent", "95")
    assert state(t, "06:00").read_text().split()[-1] == "1"
    run("06:00", "--reset")
    assert limits(msi)[0] == 2699
    assert (msi / "hwmon" / "hwmon0" / "power1_cap").read_text().strip() == "130000000"
    print("PASS: power-cap promotion restores the original pre-mining baseline")

    # Competing miners on one card must not overwrite its initial baseline.
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(lambda _: run("0a:00", "--core-max", "1800"), range(2)))
    run("0a:00", "--reset")
    assert limits(giga)[0] == 2694
    print("PASS: concurrent same-card requests retain baseline under the PCI lock")

    # A neutral per-algorithm profile must clear the previous algorithm's clocks
    # and voltage under one PCI lock, rather than inheriting a stale undervolt.
    run("03:00", "--replace-profile", "--core-max", "2200",
        "--mem-max", "1150", "--voltage-offset", "-250")
    assert limits(rx7600) == (2200, 1150, -250)
    run("03:00", "--replace-profile", "--core-max", "2000")
    assert limits(rx7600) == (2000, 1125, 0), "Omitted memory/voltage retained previous algo"
    assert state(t, "03:00").exists(), "Partial profile lost original baseline"
    run("03:00", "--replace-profile", "--mem-max", "1175")
    assert limits(rx7600) == (2900, 1175, 0), "Omitted core kept previous algo"
    run("03:00", "--replace-profile")
    assert limits(rx7600) == (2900, 1125, 0), "Fully neutral profile did not restore baseline"
    assert not state(t, "03:00").exists()
    assert (rx7600 / "power_dpm_force_performance_level").read_text().strip() == "auto"
    print("PASS: tuned -> core-only -> memory-only -> neutral clears stale clocks/voltage")

    # A previous power cap must not carry over to a zero/omitted-power profile.
    run("03:00", "--replace-profile", "--core-max", "2300",
        "--power-percent", "95")
    assert (rx7600 / "hwmon" / "hwmon0" / "power1_cap").read_text().strip() == "123500000"
    run("03:00", "--replace-profile", "--core-max", "2100")
    assert (rx7600 / "hwmon" / "hwmon0" / "power1_cap").read_text().strip() == "130000000"
    run("03:00", "--reset")
    assert limits(rx7600) == (2900, 1125, 0)
    print("PASS: profile replacement drops stale power caps and preserves reset")

    # Preserve per-device isolation while switching on
    # one card cannot disturb another card's clocks or original snapshot.
    run("06:00", "--replace-profile", "--core-max", "1800", "--mem-max", "1150")
    run("0a:00", "--replace-profile", "--core-max", "2000", "--mem-max", "1190")
    run("06:00", "--replace-profile", "--mem-max", "1100")
    assert limits(msi) == (2699, 1100, 0)
    assert limits(giga) == (2000, 1190, 0)
    run("06:00", "--replace-profile", "--dry-run")
    assert limits(msi) == (2699, 1100, 0), "Dry-run unexpectedly wrote registers"
    run("06:00", "--replace-profile")
    assert limits(msi) == (2699, 1094, 0)
    assert limits(giga) == (2000, 1190, 0)
    run("0a:00", "--reset")
    assert limits(giga) == (2694, 1094, 0)
    print("PASS: independent cards, baseline voltage preserved, no-write dry-run")

    run("03:00", "--reset", "--replace-profile", ok=False)
    assert not state(t, "03:00").exists()
    print("PASS: conflicting reset/replacement arguments rejected")

    # If a previously applied profile cannot restore due to a silent OD commit
    # failure, keep the recovery snapshot and abort replacement.
    run("03:00", "--replace-profile", "--core-max", "2200")
    run("03:00", "--replace-profile", "--mem-max", "1180",
        reject=True, ok=False)
    assert state(t, "03:00").exists(), "Restore failure destroyed the baseline"
    assert limits(rx7600)[0] == 2200
    run("03:00", "--reset")
    assert limits(rx7600) == (2900, 1125, 0)
    print("PASS: failed profile replacement retains baseline and aborts safely")

    # A malformed/out-of-range incoming profile must fail preflight BEFORE
    # restoring or overwriting the current known-good OC.
    run("03:00", "--replace-profile", "--core-max", "2200")
    run("03:00", "--replace-profile", "--core-max", "99999", ok=False)
    assert limits(rx7600) == (2200, 1125, 0)
    assert state(t, "03:00").exists()
    run("03:00", "--reset")
    run("06:00", "--replace-profile", "--core-max", "1800")
    run("06:00", "--replace-profile", "--core-max", "1900",
        "--voltage-offset", "-300", ok=False)
    assert limits(msi) == (1800, 1094, 0), "Invalid voltage request altered previous profile"
    run("06:00", "--reset")
    print("PASS: invalid incoming profile leaves current known-good settings intact")

print("ALL_AMD_OC_MOCK_TESTS_PASSED")
