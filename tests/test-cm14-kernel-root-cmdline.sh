#!/usr/bin/env bash
# Verify the A-only diagnostic kernel ignores the Fire OS root dm-0 argument.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="$ROOT/patches/kernel/biscuit-kernel-force-ramdisk-root-a-test.patch"
STAGE="$ROOT/scripts/stage-cm14.1-tree.sh"

for line in \
  '+CONFIG_CMDLINE="console=tty0 console=ttyMT0,921600n1 root=/dev/ram rdinit=/init vmalloc=496M slub_max_order=0 slub_debug=O loglevel=8 initcall_debug gpt bootopt=64S3,32N2,32N2 androidboot.hardware=mt8163 androidboot.selinux=permissive androidboot.slot_suffix=_a buildvariant=userdebug"' \
  '+# CONFIG_CMDLINE_FROM_BOOTLOADER is not set' \
  '+CONFIG_CMDLINE_FORCE=y'; do
  grep -Fqx "$line" "$PATCH"
done

grep -Fqx 'apply_patch "$KERNEL_DEST" 4 "$REPO_ROOT/patches/kernel/biscuit-kernel-force-ramdisk-root-a-test.patch"' "$STAGE"
! grep -q '^[-+]CONFIG_DM_\|^[-+]# CONFIG_DM_' "$PATCH"

echo 'PASS CM14 A-only ramdisk-root kernel patch contract'
