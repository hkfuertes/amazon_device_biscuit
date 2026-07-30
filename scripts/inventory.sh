#!/usr/bin/env bash
# inventory.sh — Scan workspace/upstream/ and report presence of Biscuit-relevant components.
# Does NOT modify upstream. Safe to re-run at any time.
# Usage: scripts/inventory.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM="$REPO_ROOT/workspace/upstream"

# ── helpers ─────────────────────────────────────────────────────────────────
PASS=0; FAIL=0
check() {
  local label="$1" mode="$2"; shift 2
  # Remaining args are candidate paths (any match = PRESENT)
  local status="MISSING"
  for path in "$@"; do
    if [[ -e "$UPSTREAM/$path" ]]; then
      status="PRESENT"; break
    fi
  done
  if [[ "$status" == "PRESENT" ]]; then (( ++PASS )); else (( ++FAIL )); fi
  printf "%-12s  %-17s  %s\n" "$status" "$mode" "$label"
}

# ── guard ────────────────────────────────────────────────────────────────────
if [[ ! -d "$UPSTREAM" ]] || [[ -z "$(ls -A "$UPSTREAM" | grep -v '^\.gitkeep$')" ]]; then
  echo "ERROR: workspace/upstream/ is empty. Run scripts/preflight.sh first."
  exit 1
fi

echo "=== Biscuit Amazon Source Inventory ==="
echo "upstream: $UPSTREAM"
echo "----------------------------------------"
printf "%-12s  %-17s  %s\n" "STATUS" "USE-MODE" "COMPONENT"
echo "------------ -----------------  -----------------------------------------------"

echo ""
echo "-- Kernel --"
check "kernel-src"      "external-patch"  "kernel" "kernel/amazon/biscuit"
check "defconfig"       "generated-copy"  "kernel/arch/arm/configs/biscuit_defconfig" \
                                          "kernel/arch/arm/configs/mt8163_defconfig" \
                                          "kernel/arch/arm/configs/amazon_defconfig"
check "dts"             "external-patch"  "kernel/arch/arm/boot/dts"

echo ""
echo "-- Init / Boot --"
check "init.rc"         "generated-copy"  "device/amazon/biscuit/init.rc" \
                                          "device/amazon/biscuit/init.biscuit.rc"
check "fstab"           "generated-copy"  "device/amazon/biscuit/fstab.mt8163" \
                                          "device/amazon/biscuit/fstab.biscuit" \
                                          "device/amazon/biscuit/fstab.mt8127"
check "ueventd.rc"      "generated-copy"  "device/amazon/biscuit/ueventd.rc" \
                                          "device/amazon/biscuit/ueventd.biscuit.rc"
check "init.mt8163.rc"  "generated-copy"  "device/amazon/biscuit/init.mt8163.rc" \
                                          "device/amazon/biscuit/init.mt8127.rc"

echo ""
echo "-- WiFi --"
check "wifi-driver"     "external-patch"  "kernel/drivers/net/wireless/realtek" \
                                          "kernel/drivers/net/wireless/mt66xx" \
                                          "kernel/drivers/net/wireless/rtl8189fs"
check "wifi-firmware"   "missing"         "vendor/firmware/rtlwifi" \
                                          "vendor/firmware/mt6625l_patch.bin"
check "wpa_supplicant"  "symlink"         "device/amazon/biscuit/wpa_supplicant.conf" \
                                          "device/amazon/biscuit/wpa_supplicant_overlay.conf"
check "wifi-init"       "generated-copy"  "device/amazon/biscuit/init.wifi.rc"
check "wifi-props"      "generated-copy"  "device/amazon/biscuit/system.prop"

echo ""
echo "-- Audio Playback --"
check "audio-hal"       "external-patch"  "hardware/amazon/audio" \
                                          "hardware/mediatek/audio"
check "mixer_paths"     "generated-copy"  "device/amazon/biscuit/audio/mixer_paths.xml"
check "audio_policy"    "generated-copy"  "device/amazon/biscuit/audio/audio_policy.conf"
check "tinyalsa"        "as-is"           "external/tinyalsa"
check "audio-effects"   "symlink"         "device/amazon/biscuit/audio/audio_effects.conf"

echo ""
echo "-- Microphone / Recording --"
# Reuse mixer_paths / audio_policy checks above; capture section lives in same files.
# Check for mic-specific extras:
check "ueventd-audio"   "generated-copy"  "device/amazon/biscuit/ueventd.rc" \
                                          "device/amazon/biscuit/ueventd.biscuit.rc"
check "audio-proc"      "symlink"         "device/amazon/biscuit/audio/audio_effects.conf" \
                                          "device/amazon/biscuit/audio/audio_effects_vendor.conf"

echo ""
echo "-- Firmware / Blobs --"
check "wifi-fw-blob"    "missing"         "vendor/firmware/rtlwifi" \
                                          "vendor/firmware/rtl8189fs_fw.bin"
check "bt-firmware"     "missing"         "vendor/firmware/mt6625l" \
                                          "vendor/firmware/BCM43xx"
check "gpu-blobs"       "missing"         "vendor/lib/egl"
check "codec-libs"      "missing"         "vendor/lib/libmtkac3dec.so" \
                                          "vendor/lib/libMtkOmxAudioDecBase.so"

echo ""
echo "-- Device Build / Config --"
check "device.mk"       "external-patch"  "device/amazon/biscuit/device.mk"
check "BoardConfig"     "external-patch"  "device/amazon/biscuit/BoardConfig.mk"
check "AndroidProducts" "generated-copy"  "device/amazon/biscuit/AndroidProducts.mk"
check "sepolicy"        "generated-copy"  "device/amazon/biscuit/sepolicy"

echo ""
echo "========================================"
echo "  PRESENT: $PASS    MISSING: $FAIL"
echo "========================================"

if [[ "$FAIL" -gt 0 && "$PASS" -eq 0 ]]; then
  echo "All components missing — upstream may be empty or tarball structure differs."
  echo "Run preflight.sh first, then re-run this script."
  exit 2
fi

if [[ "$FAIL" -gt 0 ]]; then
  echo "Some components missing — see above. Check docs/amazon-source-inventory.md for details."
  exit 1
fi

echo "All expected components found."
