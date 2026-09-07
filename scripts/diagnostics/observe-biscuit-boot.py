#!/usr/bin/env python3
"""Observe one boot for 90 seconds. Never reboot, flash, mount, or change ADB auth."""
from datetime import datetime
from pathlib import Path
import re
import subprocess
import sys
import time

SERIAL = "G090L91073533XR7"
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "workspace/diagnostics/cm14-adb-boot-probe"


def state_from_devices(text):
    rows = [line.split() for line in text.splitlines()]
    return next((row[1] for row in rows if len(row) >= 2 and row[0] == SERIAL), "absent")


def adb(*args):
    try:
        return subprocess.run(["adb", *args], capture_output=True, timeout=8)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(args, 124, b"", b"ADB query timed out")


def main():
    assert len(sys.argv) == 2 and re.fullmatch(r"[a-z0-9-]{1,64}", sys.argv[1]), "Pass a test label"
    label = sys.argv[1]
    # Regression: unauthorized is a real transport, not absence.
    for expected in ("device", "recovery", "sideload", "offline", "unauthorized"):
        assert state_from_devices(f"List of devices attached\n{SERIAL}\t{expected}\n") == expected
    assert state_from_devices("List of devices attached\nother-device\tdevice\n") == "absent"
    OUT.mkdir(parents=True, exist_ok=True)
    deadline, previous = time.monotonic() + 90, None
    while time.monotonic() < deadline:
        result = adb("devices", "-l")
        state = state_from_devices(result.stdout.decode(errors="replace")) if result.returncode == 0 else "query-error"
        if state != previous:
            print(datetime.now().isoformat(), "ADB=" + state, flush=True)
            previous = state
        if state == "device":
            identity = adb("-s", SERIAL, "shell",
                           "/sbin/busybox uname -a; /sbin/busybox cat /proc/uptime /default.prop /proc/cmdline /proc/mounts")
            (OUT / f"{label}.identity.log").write_bytes(identity.stdout + identity.stderr)
            print(identity.stdout.decode(errors="replace"), flush=True)
            if b"ro.biscuit.bootprobe=adb-only-v1" in identity.stdout:
                result = adb("-s", SERIAL, "exec-out", "/sbin/busybox dmesg")
                (OUT / f"{label}.dmesg.log").write_bytes(result.stdout + result.stderr)
                print("Probe reached ADB; dmesg status:", result.returncode, flush=True)
            else:
                print("Device online, but probe identity was not confirmed.", flush=True)
            return
        time.sleep(1)
    print("Observation deadline reached.", flush=True)


if __name__ == "__main__":
    main()
