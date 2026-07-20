#!/usr/bin/env bash
# build-boot-img.sh — Assemble boot.img from kernel + CM12 ramdisk.
#
# Requires:
#   - workspace/device/amazon/biscuit/prebuilt/kernel   (from build-kernel.sh)
#   - RAMDISK_IMG env var or workspace/out/ramdisk.img  (from CM12 build via build.sh)
#   - mkbootimg available (in PATH or biscuit-kernel-builder image)
#
# BLOCKER as of issue-06:
#   CM12 source not synced → no ramdisk.img yet.
#   Run 'repo sync' in workspace/cm12, then build.sh to get the ramdisk,
#   then re-run this script.
#
# Output: workspace/out/boot.img

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREBUILT_DIR="$REPO_ROOT/workspace/device/amazon/biscuit/prebuilt"
CM12_OUT="$REPO_ROOT/workspace/cm12/out-docker/target/product/biscuit"
OUT_DIR="$REPO_ROOT/workspace/out"

KERNEL="$PREBUILT_DIR/kernel"

# Ramdisk: check env first, then CM12 out
RAMDISK="${RAMDISK_IMG:-$CM12_OUT/ramdisk.img}"

# Boot image parameters from BoardConfig.mk
BASE=0x40000000
KERNEL_OFFSET=0x00008000
RAMDISK_OFFSET=0x04f88000
TAGS_OFFSET=0x0df88000
PAGESIZE=2048
CMDLINE="bootopt=64S3,32N2,64N2 androidboot.selinux=permissive"

# ── Guards ───────────────────────────────────────────────────────────────────
if [[ ! -f "$KERNEL" ]]; then
  echo "ERROR: Kernel not found at $KERNEL"
  echo "       Run workspace/scripts/build-kernel.sh first."
  exit 1
fi

if [[ ! -f "$RAMDISK" ]]; then
  echo "ERROR: Ramdisk not found."
  echo ""
  echo "  BLOCKER: CM12 source not synced. Steps to unblock:"
  echo "    1. cd workspace/cm12 && repo init -u https://github.com/CyanogenMod/android -b cm-12.1"
  echo "    2. repo sync -j4"
  echo "    3. Re-run workspace/scripts/preflight.sh   (creates device tree symlink)"
  echo "    4. workspace/scripts/build.sh              (produces ramdisk.img in out-docker/)"
  echo "    5. Re-run this script."
  echo ""
  echo "  Or set: RAMDISK_IMG=<path/to/ramdisk.img> $0"
  exit 1
fi

# ── mkbootimg: find in PATH, CM12 out, or fall back to abootimg ─────────────
MKBOOTIMG=""
if command -v mkbootimg >/dev/null 2>&1; then
  MKBOOTIMG="mkbootimg"
elif [[ -x "$REPO_ROOT/workspace/cm12/out-docker/host/linux-x86/bin/mkbootimg" ]]; then
  MKBOOTIMG="$REPO_ROOT/workspace/cm12/out-docker/host/linux-x86/bin/mkbootimg"
elif command -v abootimg >/dev/null 2>&1; then
  # ponytail: abootimg fallback — same format, different CLI; handled below
  MKBOOTIMG="abootimg"
else
  echo "ERROR: no mkbootimg or abootimg found."
  echo "       Either:"
  echo "         - Build CM12 first (build.sh produces out-docker/host/linux-x86/bin/mkbootimg)"
  echo "         - apt-get install -y abootimg"
  exit 1
fi
echo "Using: $MKBOOTIMG"

mkdir -p "$OUT_DIR"

BOOT_IMG="$OUT_DIR/boot.img"

echo "Assembling boot.img ..."
echo "  kernel:        $KERNEL"
echo "  ramdisk:       $RAMDISK"
echo "  base:          $(printf '0x%08x' $BASE)"
echo "  kernel_offset: $(printf '0x%08x' $KERNEL_OFFSET)"
echo "  ramdisk_offset:$(printf '0x%08x' $RAMDISK_OFFSET)"
echo "  tags_offset:   $(printf '0x%08x' $TAGS_OFFSET)"
echo "  pagesize:      $PAGESIZE"

if [[ "$(basename $MKBOOTIMG)" == "abootimg" ]]; then
  # abootimg syntax: uses a config file
  CFG="$OUT_DIR/bootimg.cfg"
  printf 'pagesize = 0x%x\nkerneladdr = 0x%x\nramdiskaddr = 0x%x\ntagsaddr = 0x%x\ncmdline = %s\n' \
    "$PAGESIZE" \
    $(( BASE + KERNEL_OFFSET )) \
    $(( BASE + RAMDISK_OFFSET )) \
    $(( BASE + TAGS_OFFSET )) \
    "$CMDLINE" > "$CFG"
  abootimg --create "$BOOT_IMG" -f "$CFG" -k "$KERNEL" -r "$RAMDISK"
else
  "$MKBOOTIMG" \
    --kernel   "$KERNEL" \
    --ramdisk  "$RAMDISK" \
    --base     "$BASE" \
    --kernel_offset   "$KERNEL_OFFSET" \
    --ramdisk_offset  "$RAMDISK_OFFSET" \
    --tags_offset     "$TAGS_OFFSET" \
    --pagesize "$PAGESIZE" \
    --cmdline  "$CMDLINE" \
    -o "$BOOT_IMG"
fi

sha256sum "$BOOT_IMG" | tee "$BOOT_IMG.sha256"

echo ""
echo "boot.img ready: $BOOT_IMG"
echo ""
echo "Flash via TWRP:       adb push $BOOT_IMG /sdcard/ && adb shell twrp flash boot /sdcard/boot.img"
echo "Flash via hacked fb:  fastboot flash boot $BOOT_IMG   (only if 'fastboot getvar all' shows amonet)"
