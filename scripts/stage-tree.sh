#!/usr/bin/env bash
# Stage the Biscuit CM14.1 overlay and exact Fire OS 6 kernel source.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM14="${CM14:-$REPO_ROOT/workspace/cm14.1}"
FIREOS_RELEASE="6.5.7.1"
FIREOS_URL="https://fireos-audio-src.s3.amazonaws.com/dMUQiRDxI3hFuRDaF0WTumrp71/Echo_Dot_src-6.5.7.1-20251024.tar.bz2"
FIREOS_SHA256="2f6b7eed8c09cecf7633f01909c6a4085bef691c29ed0d106c75e7b48c7b4721"
VERITY_KEY_SHA256="feb0c591f259639dfbdc58a82aee2c64f55c039f3b764aae91f6d3d14deec5b4"
ARCHIVE="$REPO_ROOT/workspace/downloads/$(basename "$FIREOS_URL")"
SOURCE_DIR="$REPO_ROOT/workspace/upstream/amazon-echo-dot-$FIREOS_RELEASE"
KERNEL_ARCHIVE_PATH="kernel/mediatek/mt8163/3.18_hl"
KERNEL_DEST="$CM14/kernel/amazon/biscuit"
KERNEL_SUPPORT="$CM14/device/amazon/biscuit/kernel-build-support"

[[ -d "$CM14/build" ]] || { echo "ERROR: CM14.1 not synced at $CM14" >&2; exit 1; }
[[ -d "$CM14/device/amazon/mt8163-common" ]] || { echo "ERROR: MT8163 common source missing; run scripts/sync.sh" >&2; exit 1; }
[[ -d "$CM14/hardware/amazon" ]] || { echo "ERROR: Amazon hardware source missing; run scripts/sync.sh" >&2; exit 1; }

copy_dir() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude .git --exclude .repo "$src/" "$dst/"
  else
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    find "$dst" \( -name .git -o -name .repo \) -prune -exec rm -rf {} +
  fi
}

drop_legacy_radio_block() {
  local init_rc="$CM14/device/amazon/mt8163-common/rootdir/etc/init.mt8163.rc"
  grep -Fqx 'service conn_launcher /system/bin/6620_launcher -p /system/etc/firmware/' "$init_rc" || return 0
  python3 - "$init_rc" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
old = '''service wmtLoader /system/bin/wmt_loader
    user root
    group root
    oneshot
    disabled

service conn_launcher /system/bin/6620_launcher -p /system/etc/firmware/
    user root
    group root system
    disabled

on property:ro.product.device=biscuit
    chmod 0660 /dev/stpwmt
    chmod 0660 /dev/wmtWifi
    chmod 0660 /dev/stpbt
    chown system system /dev/stpwmt
    chown system system /dev/wmtWifi
    chown bluetooth bluetooth /dev/stpbt
    start wmtLoader
    start conn_launcher

'''
if old not in text:
    raise SystemExit('legacy Biscuit radio block not found')
path.write_text(text.replace(old, '', 1))
PY
  echo "Removed obsolete 64-bit Biscuit radio launchers."
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

copy_dir "$REPO_ROOT/device/amazon/biscuit" "$CM14/device/amazon/biscuit"
copy_dir "$REPO_ROOT/vendor/amazon" "$CM14/vendor/amazon"
mkdir -p \
  "$CM14/frameworks/av/media/libstagefright/codecs/flac/dec" \
  "$CM14/frameworks/av/media/libstagefright/flac/dec"
drop_legacy_radio_block
FULL_PATCH_STATE_DIR="$CM14/.repo/biscuit-patch-state"
FULL_PATCH_STATE="$FULL_PATCH_STATE_DIR/full-p1.sha256"
FULL_PATCH_MANIFEST="$((LC_ALL=C find "$REPO_ROOT/patches/full" -maxdepth 1 -type f -name '*.patch' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) | sha256sum | awk '{print $1}')"
if [[ ! -f "$FULL_PATCH_STATE" || "$(cat "$FULL_PATCH_STATE")" != "$FULL_PATCH_MANIFEST" ]]; then
  git -C "$CM14/hardware/amazon" checkout -- libshims/Android.mk
  rm -rf "$CM14/hardware/amazon/audio" "$CM14/hardware/amazon/libshims/libtinyalsa"
fi
if [[ -f "$CM14/system/core/liblog/logger_write.c" ]] &&
   (( $(grep -c 'LIBLOG_ABI_PUBLIC int lab126_log_write' "$CM14/system/core/liblog/logger_write.c" || true) > 1 )); then
  git -C "$CM14/system/core" checkout -- liblog/logger_write.c
fi
PATCH_REAPPLY=1 PATCH_STATE_DIR="$FULL_PATCH_STATE_DIR" \
  "$REPO_ROOT/scripts/apply-patches.sh" "$CM14" 1 "$REPO_ROOT/patches/full"
CM14="$CM14" "$REPO_ROOT/scripts/extract-fireos6-blobs.sh"

rm -rf "$KERNEL_DEST" "$KERNEL_SUPPORT"
mkdir -p "$KERNEL_DEST" "$KERNEL_SUPPORT/include/generated"
tar --no-same-owner --no-same-permissions -xf "$SOURCE_DIR/platform.tar" \
  -C "$KERNEL_DEST" --strip-components=4 "$KERNEL_ARCHIVE_PATH"
tar -xOf "$SOURCE_DIR/platform.tar" \
  device/amazon/common/verity/amazon_verity.x509.pem >"$KERNEL_SUPPORT/verity-keys"
install -m 0644 "$SOURCE_DIR/prebuilt/include/generated/trapz_generated_kernel.h" \
  "$KERNEL_SUPPORT/include/generated/trapz_generated_kernel.h"
printf '%s  %s\n' "$VERITY_KEY_SHA256" "$KERNEL_SUPPORT/verity-keys" | sha256sum -c -
"$REPO_ROOT/scripts/apply-patches.sh" "$KERNEL_DEST" 4 "$REPO_ROOT/patches/kernel"

[[ -f "$KERNEL_DEST/Makefile" && \
   -f "$KERNEL_DEST/arch/arm/configs/biscuit_defconfig" && \
   -f "$KERNEL_SUPPORT/verity-keys" && \
   -f "$KERNEL_SUPPORT/include/generated/trapz_generated_kernel.h" ]] || {
  echo "ERROR: Fire OS 6 Biscuit kernel staging is incomplete" >&2
  exit 1
}

echo "Staged CM14.1 Biscuit overlay, Fire OS 6 blobs, and Fire OS 6 kernel source."
