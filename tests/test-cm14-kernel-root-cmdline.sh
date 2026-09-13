#!/usr/bin/env bash
# Verify the permanent Fire OS root dm-0 bypass and headless root ADB contract.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="$ROOT/patches/kernel/biscuit-kernel-force-ramdisk-root.patch"
ADB_PATCH="$ROOT/patches/cm14/cm14.1-insecure-adb-default-props.patch"
STAGE="$ROOT/scripts/stage-cm14.1-tree.sh"
BOARD="$ROOT/cm14.1/device/amazon/biscuit/BoardConfig.mk"

for line in \
  '+CONFIG_CMDLINE="console=tty0 console=ttyMT0,921600n1 root=/dev/ram rdinit=/init vmalloc=496M slub_max_order=0 slub_debug=O loglevel=8 initcall_debug gpt bootopt=64S3,32N2,32N2 androidboot.hardware=mt8163 androidboot.selinux=permissive buildvariant=userdebug"' \
  '+# CONFIG_CMDLINE_FROM_BOOTLOADER is not set' \
  '+CONFIG_CMDLINE_FORCE=y'; do
  grep -Fqx "$line" "$PATCH"
done

! grep -q 'androidboot.slot_suffix' "$PATCH"
! grep -q '^[-+]CONFIG_DM_\|^[-+]# CONFIG_DM_' "$PATCH"
grep -Fqx 'apply_patch "$KERNEL_DEST" 4 "$REPO_ROOT/patches/kernel/biscuit-kernel-force-ramdisk-root.patch"' "$STAGE"
grep -Fqx 'apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-insecure-adb-default-props.patch"' "$STAGE"
grep -Fqx 'TARGET_FORCE_INSECURE_ADB := true' "$BOARD"
for line in \
  '+ifeq ($(TARGET_FORCE_INSECURE_ADB),true)' \
  '+ADDITIONAL_DEFAULT_PROPERTIES := $(filter-out ro.adb.secure=% ro.secure=% cm.service.adb.root=%,$(ADDITIONAL_DEFAULT_PROPERTIES))' \
  '+    ro.adb.secure=0 \' \
  '+    ro.secure=0 \' \
  '+    cm.service.adb.root=1'; do
  grep -Fqx "$line" "$ADB_PATCH"
done

echo 'PASS CM14 persistent ramdisk-root and root-ADB contract'
