#!/usr/bin/env bash
# Stage the CM14.1 Biscuit overlay and exact FireOS 6 kernel source.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM14="${CM14:-$REPO_ROOT/workspace/cm14.1}"
OVERLAY="$REPO_ROOT/cm14.1"

FIREOS_RELEASE="6.5.7.1"
FIREOS_URL="https://fireos-audio-src.s3.amazonaws.com/dMUQiRDxI3hFuRDaF0WTumrp71/Echo_Dot_src-6.5.7.1-20251024.tar.bz2"
FIREOS_SHA256="2f6b7eed8c09cecf7633f01909c6a4085bef691c29ed0d106c75e7b48c7b4721"
VERITY_KEY_SHA256="feb0c591f259639dfbdc58a82aee2c64f55c039f3b764aae91f6d3d14deec5b4"
ARCHIVE="$REPO_ROOT/workspace/downloads/$(basename "$FIREOS_URL")"
SOURCE_DIR="$REPO_ROOT/workspace/upstream/amazon-echo-dot-$FIREOS_RELEASE"
KERNEL_ARCHIVE_PATH="kernel/mediatek/mt8163/3.18_hl"
KERNEL_DEST="$CM14/kernel/amazon/biscuit"
KERNEL_SUPPORT="$CM14/device/amazon/biscuit/kernel-build-support"

apply_patch() {
  local root="$1" strip="$2" patch_file="$3"

  if patch --batch --forward --fuzz=0 --dry-run -d "$root" -p"$strip" <"$patch_file" >/dev/null; then
    patch --batch --forward --fuzz=0 -d "$root" -p"$strip" <"$patch_file"
  elif patch --batch --forward --fuzz=0 --dry-run -R -d "$root" -p"$strip" <"$patch_file" >/dev/null; then
    echo "Patch already staged: ${patch_file#$REPO_ROOT/}"
  else
    echo "ERROR: patch does not apply cleanly: $patch_file" >&2
    return 1
  fi
}

[[ -d "$CM14/build" ]] || { echo "ERROR: CM14.1 not synced at $CM14" >&2; exit 1; }
[[ -d "$CM14/device/amazon/mt8163-common" ]] || { echo "ERROR: MT8163 common source missing; run scripts/sync-cm14.1.sh" >&2; exit 1; }
[[ -d "$CM14/hardware/amazon" ]] || { echo "ERROR: Amazon hardware source missing; run scripts/sync-cm14.1.sh" >&2; exit 1; }

copy_dir() {
  local src="$1" dst="$2"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  find "$dst" \( -name .git -o -name .repo \) -prune -exec rm -rf {} +
}

mkdir -p "$(dirname "$ARCHIVE")" "$(dirname "$SOURCE_DIR")"
if [[ ! -f "$ARCHIVE" ]]; then
  curl --fail --location --progress-bar -o "$ARCHIVE" "$FIREOS_URL"
fi
printf '%s  %s\n' "$FIREOS_SHA256" "$ARCHIVE" | sha256sum -c -

if [[ ! -f "$SOURCE_DIR/platform.tar" || \
      ! -f "$SOURCE_DIR/prebuilt/include/generated/trapz_generated_kernel.h" ]]; then
  rm -rf "$SOURCE_DIR"
  mkdir -p "$SOURCE_DIR"
  tar --no-same-owner --no-same-permissions -xjf "$ARCHIVE" -C "$SOURCE_DIR" \
    platform.tar prebuilt
fi

copy_dir "$OVERLAY/device/amazon/biscuit" "$CM14/device/amazon/biscuit"
copy_dir "$OVERLAY/vendor/amazon" "$CM14/vendor/amazon"
FSTAB="$CM14/device/amazon/mt8163-common/rootdir/etc/fstab.mt8163"
if grep -qE '^/dev/block/platform/bootdevice/by-name/system[[:space:]]+/system.*slotselect' "$FSTAB" && \
   grep -qE '^/dev/block/platform/bootdevice/by-name/boot[[:space:]]+/boot.*slotselect' "$FSTAB"; then
  echo "Amonet v2 slotselect fstab already staged."
else
  apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-amonet-fstab.patch"
fi
grep -qE '^/dev/block/platform/bootdevice/by-name/system[[:space:]]+/system.*slotselect' "$FSTAB"
grep -qE '^/dev/block/platform/bootdevice/by-name/boot[[:space:]]+/boot.*slotselect' "$FSTAB"
! grep -qE 'boot_[ab]_x' "$FSTAB"
! grep -q '/dev/block/platform/soc/' "$FSTAB"
apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-headless-system-props.patch"
apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-software-egl-fallback.patch"
apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-hwui-egl-config-fallback.patch"
apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-amazon-audio-wrapper.patch"
CM14="$CM14" "$REPO_ROOT/scripts/extract-cm14-fireos6-audio-blobs.sh"

rm -rf "$KERNEL_DEST" "$KERNEL_SUPPORT"
mkdir -p "$KERNEL_DEST" "$KERNEL_SUPPORT/include/generated"
tar --no-same-owner --no-same-permissions -xf "$SOURCE_DIR/platform.tar" \
  -C "$KERNEL_DEST" --strip-components=4 "$KERNEL_ARCHIVE_PATH"
tar -xOf "$SOURCE_DIR/platform.tar" \
  device/amazon/common/verity/amazon_verity.x509.pem >"$KERNEL_SUPPORT/verity-keys"
install -m 0644 "$SOURCE_DIR/prebuilt/include/generated/trapz_generated_kernel.h" \
  "$KERNEL_SUPPORT/include/generated/trapz_generated_kernel.h"
printf '%s  %s\n' "$VERITY_KEY_SHA256" "$KERNEL_SUPPORT/verity-keys" | sha256sum -c -
apply_patch "$KERNEL_DEST" 4 "$REPO_ROOT/patches/kernel/biscuit-kernel-netfilter-xt-compat-percpu.patch"

[[ -f "$KERNEL_DEST/Makefile" && \
   -f "$KERNEL_DEST/arch/arm/configs/biscuit_defconfig" && \
   -f "$KERNEL_SUPPORT/verity-keys" && \
   -f "$KERNEL_SUPPORT/include/generated/trapz_generated_kernel.h" ]] || {
  echo "ERROR: FireOS 6 Biscuit kernel staging is incomplete" >&2
  exit 1
}

echo "Staged CM14.1 Biscuit FireOS 6 kernel source and audio blob closure."
