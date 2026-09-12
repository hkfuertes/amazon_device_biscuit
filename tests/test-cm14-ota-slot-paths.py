#!/usr/bin/env python3
"""Regression checks for amonet v2 TWRP OTA block targets and assertions."""

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "cm14.1/device/amazon/biscuit/releasetools.py"
DEFAULT_ASSERTION = (
    'assert(getprop("ro.product.device") == "biscuit" || '
    'abort("E3004: This package is for device: biscuit"));'
)

spec = importlib.util.spec_from_file_location("biscuit_releasetools", MODULE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Partition:
    def __init__(self, device):
        self.device = device


class Script:
    def __init__(self, statements=()):
        self.fstab = {
            "/system": Partition("/dev/block/platform/bootdevice/by-name/system"),
            "/boot": Partition("/dev/block/platform/bootdevice/by-name/boot"),
        }
        self.script = list(statements)


class Info:
    def __init__(self, statements=()):
        self.script = Script(statements)


for hook in (module.FullOTA_InstallBegin, module.IncrementalOTA_InstallBegin):
    info = Info()
    hook(info)
    assert info.script.fstab["/system"].device == "/dev/block/current-system"
    assert info.script.fstab["/boot"].device == "/dev/block/current-boot"

for hook in (module.FullOTA_Assertions, module.IncrementalOTA_Assertions):
    info = Info((DEFAULT_ASSERTION, "ui_print(\"after\");"))
    hook(info)
    assert info.script.script[0] == module._AMONET_SLOT_ASSERTION
    assert "getprop" not in info.script.script[0]
    assert "/dev/block/current-system" in info.script.script[0]
    assert "/dev/block/current-boot" in info.script.script[0]
    assert info.script.script[1] == "ui_print(\"after\");"

try:
    module.FullOTA_Assertions(Info())
except ValueError as error:
    assert str(error) == "missing default OTA device assertion"
else:
    raise AssertionError("missing default assertion did not fail closed")

board_config = (ROOT / "cm14.1/device/amazon/biscuit/BoardConfig.mk").read_text()
assert "TARGET_RELEASETOOLS_EXTENSIONS := $(LOCAL_PATH)" in board_config

print("CM14 amonet v2 OTA slot-path checks: PASS")
