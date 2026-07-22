#!/usr/bin/env bash
# Extract stock Biscuit non-GPU blobs from system.img into vendor/amazon/biscuit.
# Input: ext4 system.img from the Biscuit OTA, default workspace/extracted/biscuit-ota/system.img.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYSTEM_IMG="${1:-$REPO_ROOT/workspace/extracted/biscuit-ota/system.img}"
OUT="$REPO_ROOT/workspace/vendor/amazon/biscuit"
PROP="$OUT/proprietary"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ ! -f "$SYSTEM_IMG" ]]; then
  echo "ERROR: system.img not found: $SYSTEM_IMG" >&2
  echo "Extract Biscuit OTA to workspace/extracted/biscuit-ota/system.img or pass a path." >&2
  exit 1
fi
command -v 7z >/dev/null || { echo "ERROR: 7z required" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$PROP"

# Stock Biscuit headless/no-GPU set. Intentionally excludes libGLES_mali,
# gralloc.mt8163.mali, libgpu_aux, and ro.hardware.gralloc=mt8163.mali.
files=(
  lib/egl/egl.cfg
  lib/hw/gralloc.mt8163.so
  lib/hw/hwcomposer.mt8163.so
  lib/libGdmaScalerPipe.so
  lib/libbwc.so
  lib/libdpframework.so
  lib/libgralloc_extra.so
  lib/libgui_ext.so
  lib/libion_mtk.so
  lib/libm4u.so
  lib/libstlport.so
  lib/libui_ext.so
  lib64/hw/gralloc.mt8163.so
  lib64/hw/hwcomposer.mt8163.so
  lib64/libbwc.so
  lib64/libdpframework.so
  lib64/libgralloc_extra.so
  lib64/libion_mtk.so
  lib64/libm4u.so
  lib64/libstlport.so
  bin/idme
  bin/devicetype_service
  lib/hw/keystore.mt8163.so
  lib/libtz_uree.so
  lib64/hw/keystore.mt8163.so
  lib64/libtz_uree.so
  bin/6620_launcher
  bin/wmt_loader
  etc/firmware/ROMv2_lm_patch_1_0_hdr.bin
  etc/firmware/ROMv2_lm_patch_1_1_hdr.bin
  etc/firmware/WIFI_RAM_CODE_8163
  etc/firmware/WMT_SOC.cfg
  etc/wifi/p2p_supplicant_overlay.conf
  etc/wifi/wpa_supplicant.conf
  etc/wifi/wpa_supplicant_overlay.conf
  bin/linker64
  lib64/libc.so
  lib64/libcutils.so
  lib64/liblog.so
  lib64/libm.so
  lib64/libsigchain.so
  lib64/libstdc++.so
  lib/libbt-vendor.so
  lib/libbluetooth_mtk.so
  lib/libnvram.so
  lib/libnvram_platform.so
  lib/libcustom_nvram.so
)

for f in "${files[@]}"; do
  rm -rf "$TMP"/*
  # 7z returns non-zero on this ext4 image after extracting some files; trust the output file.
  7z x -y -o"$TMP" "$SYSTEM_IMG" "$f" >/dev/null 2>&1 || true
  if [[ ! -f "$TMP/$f" ]]; then
    echo "ERROR: missing in system.img: $f" >&2
    exit 1
  fi
  install -D -m 0644 "$TMP/$f" "$PROP/$f"
done

# Force software EGL. Stock has "0 1 mali" even though Biscuit is headless/no_gpu;
# CM12 bring-up must not load libGLES_mali.
printf '0 0 android\n' > "$PROP/lib/egl/egl.cfg"

cat > "$OUT/biscuit-vendor.mk" <<'MK'
# Biscuit blobs extracted from stock Biscuit system.img.
# No-GPU/headless path: intentionally no libGLES_mali, gralloc.mt8163.mali, or libgpu_aux.

PRODUCT_COPY_FILES += \
    vendor/amazon/biscuit/proprietary/lib/egl/egl.cfg:system/lib/egl/egl.cfg \
    vendor/amazon/biscuit/proprietary/lib/hw/gralloc.mt8163.so:system/lib/hw/gralloc.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib/hw/hwcomposer.mt8163.so:system/lib/hw/hwcomposer.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib/libGdmaScalerPipe.so:system/lib/libGdmaScalerPipe.so \
    vendor/amazon/biscuit/proprietary/lib/libbwc.so:system/lib/libbwc.so \
    vendor/amazon/biscuit/proprietary/lib/libdpframework.so:system/lib/libdpframework.so \
    vendor/amazon/biscuit/proprietary/lib/libgralloc_extra.so:system/lib/libgralloc_extra.so \
    vendor/amazon/biscuit/proprietary/lib/libgui_ext.so:system/lib/libgui_ext.so \
    vendor/amazon/biscuit/proprietary/lib/libion_mtk.so:system/lib/libion_mtk.so \
    vendor/amazon/biscuit/proprietary/lib/libm4u.so:system/lib/libm4u.so \
    vendor/amazon/biscuit/proprietary/lib/libstlport.so:system/lib/libstlport.so \
    vendor/amazon/biscuit/proprietary/lib/libui_ext.so:system/lib/libui_ext.so \
    vendor/amazon/biscuit/proprietary/lib64/hw/gralloc.mt8163.so:system/lib64/hw/gralloc.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib64/hw/hwcomposer.mt8163.so:system/lib64/hw/hwcomposer.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib64/libbwc.so:system/lib64/libbwc.so \
    vendor/amazon/biscuit/proprietary/lib64/libdpframework.so:system/lib64/libdpframework.so \
    vendor/amazon/biscuit/proprietary/lib64/libgralloc_extra.so:system/lib64/libgralloc_extra.so \
    vendor/amazon/biscuit/proprietary/lib64/libion_mtk.so:system/lib64/libion_mtk.so \
    vendor/amazon/biscuit/proprietary/lib64/libm4u.so:system/lib64/libm4u.so \
    vendor/amazon/biscuit/proprietary/lib64/libstlport.so:system/lib64/libstlport.so \
    vendor/amazon/biscuit/proprietary/bin/idme:system/bin/idme \
    vendor/amazon/biscuit/proprietary/bin/devicetype_service:system/bin/devicetype_service \
    vendor/amazon/biscuit/proprietary/lib/hw/keystore.mt8163.so:system/lib/hw/keystore.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib/libtz_uree.so:system/lib/libtz_uree.so \
    vendor/amazon/biscuit/proprietary/lib64/hw/keystore.mt8163.so:system/lib64/hw/keystore.mt8163.so \
    vendor/amazon/biscuit/proprietary/lib64/libtz_uree.so:system/lib64/libtz_uree.so \
    vendor/amazon/biscuit/proprietary/bin/6620_launcher:system/bin/6620_launcher \
    vendor/amazon/biscuit/proprietary/bin/wmt_loader:system/bin/wmt_loader \
    vendor/amazon/biscuit/proprietary/etc/firmware/ROMv2_lm_patch_1_0_hdr.bin:system/etc/firmware/ROMv2_lm_patch_1_0_hdr.bin \
    vendor/amazon/biscuit/proprietary/etc/firmware/ROMv2_lm_patch_1_1_hdr.bin:system/etc/firmware/ROMv2_lm_patch_1_1_hdr.bin \
    vendor/amazon/biscuit/proprietary/etc/firmware/WIFI_RAM_CODE_8163:system/etc/firmware/WIFI_RAM_CODE_8163 \
    vendor/amazon/biscuit/proprietary/etc/firmware/WMT_SOC.cfg:system/etc/firmware/WMT_SOC.cfg \
    vendor/amazon/biscuit/proprietary/etc/wifi/p2p_supplicant_overlay.conf:system/etc/wifi/p2p_supplicant_overlay.conf \
    vendor/amazon/biscuit/proprietary/etc/wifi/wpa_supplicant.conf:system/etc/wifi/wpa_supplicant.conf \
    vendor/amazon/biscuit/proprietary/etc/wifi/wpa_supplicant_overlay.conf:system/etc/wifi/wpa_supplicant_overlay.conf \
    vendor/amazon/biscuit/proprietary/bin/linker64:system/bin/linker64 \
    vendor/amazon/biscuit/proprietary/lib64/libc.so:system/lib64/libc.so \
    vendor/amazon/biscuit/proprietary/lib64/libcutils.so:system/lib64/libcutils.so \
    vendor/amazon/biscuit/proprietary/lib64/liblog.so:system/lib64/liblog.so \
    vendor/amazon/biscuit/proprietary/lib64/libm.so:system/lib64/libm.so \
    vendor/amazon/biscuit/proprietary/lib64/libsigchain.so:system/lib64/libsigchain.so \
    vendor/amazon/biscuit/proprietary/lib64/libstdc++.so:system/lib64/libstdc++.so \
    vendor/amazon/biscuit/proprietary/lib/libbt-vendor.so:system/lib/libbt-vendor.so \
    vendor/amazon/biscuit/proprietary/lib/libbluetooth_mtk.so:system/lib/libbluetooth_mtk.so \
    vendor/amazon/biscuit/proprietary/lib/libnvram.so:system/lib/libnvram.so \
    vendor/amazon/biscuit/proprietary/lib/libnvram_platform.so:system/lib/libnvram_platform.so \
    vendor/amazon/biscuit/proprietary/lib/libcustom_nvram.so:system/lib/libcustom_nvram.so
MK

cat > "$OUT/blob-report.md" <<'MD'
# Biscuit blob report

Generated by `workspace/scripts/extract-biscuit-stock-blobs.sh` from stock Biscuit `system.img`.

Policy: no-GPU/headless. Excludes Mali EGL, Mali gralloc, and GPU helper blobs.
MD

if [[ -d "$REPO_ROOT/workspace/cm12/build" ]]; then
  "$REPO_ROOT/workspace/scripts/stage-tree.sh"
fi

echo "Extracted stock Biscuit no-GPU blobs to $OUT"
