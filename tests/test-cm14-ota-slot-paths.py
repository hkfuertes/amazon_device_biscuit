#!/usr/bin/env python3
"""Regression check for amonet v2 TWRP OTA block targets."""

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "cm14.1/device/amazon/biscuit/releasetools.py"

spec = importlib.util.spec_from_file_location("biscuit_releasetools", MODULE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Partition:
    def __init__(self, device):
        self.device = device


class Script:
    fstab = {
        "/system": Partition("/dev/block/platform/bootdevice/by-name/system"),
        "/boot": Partition("/dev/block/platform/bootdevice/by-name/boot"),
    }


class Info:
    def __init__(self):
        self.script = Script()


for hook in (module.FullOTA_InstallBegin, module.IncrementalOTA_InstallBegin):
    info = Info()
    hook(info)
    assert info.script.fstab["/system"].device == "/dev/block/current-system"
    assert info.script.fstab["/boot"].device == "/dev/block/current-boot"

board_config = (ROOT / "cm14.1/device/amazon/biscuit/BoardConfig.mk").read_text()
assert "TARGET_RELEASETOOLS_EXTENSIONS := $(LOCAL_PATH)" in board_config

print("CM14 amonet v2 OTA slot-path checks: PASS")
