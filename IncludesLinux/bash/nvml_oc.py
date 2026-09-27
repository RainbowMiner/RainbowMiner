#!/usr/bin/env python3
"""Set NVIDIA core/memory clock offsets through NVML, no X server needed.

  nvml_oc.py query
  nvml_oc.py set   --bus 01:00 [--core MHz] [--mem MHz]
  nvml_oc.py reset --bus 01:00

Needs root for set/reset. The memory offset is passed to NVML unchanged, like
RainbowMiner passes it to nvidia-settings. Errors are printed as "ERROR: ..."
and end with a non-zero exit code.
"""

import argparse
import ctypes
import sys

NVML_SUCCESS = 0


class PciInfo(ctypes.Structure):
    _fields_ = [
        ("busIdLegacy", ctypes.c_char * 16),
        ("domain", ctypes.c_uint),
        ("bus", ctypes.c_uint),
        ("device", ctypes.c_uint),
        ("pciDeviceId", ctypes.c_uint),
        ("pciSubSystemId", ctypes.c_uint),
        ("busId", ctypes.c_char * 32),
    ]


def fail(msg, code=1):
    print("ERROR: nvml_oc: %s" % msg)
    sys.exit(code)


def load():
    for name in ("libnvidia-ml.so.1", "libnvidia-ml.so"):
        try:
            return ctypes.CDLL(name)
        except OSError:
            pass
    fail("libnvidia-ml.so.1 not found")


def func(lib, name):
    try:
        return getattr(lib, name)
    except AttributeError:
        fail("%s is not supported by this driver" % name)


def errstr(lib, rc):
    try:
        f = lib.nvmlErrorString
        f.restype = ctypes.c_char_p
        return f(rc).decode("ascii", "replace")
    except Exception:
        return "error %d" % rc


def check(lib, rc, what):
    if rc != NVML_SUCCESS:
        fail("%s: %s" % (what, errstr(lib, rc)))


def full_bus_id(bus):
    # RainbowMiner uses "01:00", NVML wants "00000000:01:00.0"
    bus = bus.strip().upper()
    parts = bus.split(":")
    if len(parts) == 2:
        bus = "00000000:%s" % bus
    elif len(parts) == 3 and len(parts[0]) < 8:
        bus = "%08X:%s:%s" % (int(parts[0], 16), parts[1], parts[2])
    if "." not in bus:
        bus = bus + ".0"
    return bus


def get_handle(lib, bus):
    handle = ctypes.c_void_p()
    rc = func(lib, "nvmlDeviceGetHandleByPciBusId_v2")(full_bus_id(bus).encode("ascii"), ctypes.byref(handle))
    check(lib, rc, "no GPU at bus %s" % bus)
    return handle


def get_offset(lib, handle, name):
    val = ctypes.c_int()
    try:
        f = getattr(lib, name)
    except AttributeError:
        return None
    if f(handle, ctypes.byref(val)) != NVML_SUCCESS:
        return None
    return val.value


def set_offsets(lib, bus, core, mem):
    handle = get_handle(lib, bus)
    if core is not None:
        check(lib, func(lib, "nvmlDeviceSetGpcClkVfOffset")(handle, ctypes.c_int(core)), "core offset %d at bus %s" % (core, bus))
    if mem is not None:
        check(lib, func(lib, "nvmlDeviceSetMemClkVfOffset")(handle, ctypes.c_int(mem)), "memory offset %d at bus %s" % (mem, bus))
    print("OK bus=%s core=%s mem=%s" % (bus, get_offset(lib, handle, "nvmlDeviceGetGpcClkVfOffset"), get_offset(lib, handle, "nvmlDeviceGetMemClkVfOffset")))


def query(lib):
    count = ctypes.c_uint()
    check(lib, func(lib, "nvmlDeviceGetCount_v2")(ctypes.byref(count)), "device count")
    for i in range(count.value):
        handle = ctypes.c_void_p()
        check(lib, func(lib, "nvmlDeviceGetHandleByIndex_v2")(ctypes.c_uint(i), ctypes.byref(handle)), "device %d" % i)
        name = ctypes.create_string_buffer(96)
        lib.nvmlDeviceGetName(handle, name, ctypes.c_uint(96))
        pci = PciInfo()
        bus = "?"
        if func(lib, "nvmlDeviceGetPciInfo_v3")(handle, ctypes.byref(pci)) == NVML_SUCCESS:
            bus = "%02X:%02X" % (pci.bus, pci.device)
        print("GPU %d bus=%s name=%s core=%s mem=%s" % (
            i, bus, name.value.decode("ascii", "replace"),
            get_offset(lib, handle, "nvmlDeviceGetGpcClkVfOffset"),
            get_offset(lib, handle, "nvmlDeviceGetMemClkVfOffset")))


def main():
    ap = argparse.ArgumentParser(description="NVML clock offsets")
    ap.add_argument("action", choices=["query", "set", "reset"])
    ap.add_argument("--bus")
    ap.add_argument("--core", type=int)
    ap.add_argument("--mem", type=int)
    args = ap.parse_args()

    if args.action != "query" and not args.bus:
        fail("--bus is required for %s" % args.action)

    lib = load()
    check(lib, func(lib, "nvmlInit_v2")(), "init")
    try:
        if args.action == "query":
            query(lib)
        elif args.action == "reset":
            set_offsets(lib, args.bus, 0, 0)
        else:
            if args.core is None and args.mem is None:
                fail("nothing to set")
            set_offsets(lib, args.bus, args.core, args.mem)
    finally:
        lib.nvmlShutdown()


if __name__ == "__main__":
    main()
