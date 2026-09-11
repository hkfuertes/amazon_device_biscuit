#!/usr/bin/env bash
# Verify CM12-derived headless display and STA-only Wi-Fi compatibility patches.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM14="${CM14:-$ROOT/workspace/cm14.1}"
STAGE="$ROOT/scripts/stage-cm14.1-tree.sh"
HWC_MANIFEST="$ROOT/cm14.1/vendor/amazon/mt8163-common/biscuit-headless-hwc-files.txt"
PROP_PATCH="$ROOT/patches/cm14/cm14.1-headless-no-gpu-property.patch"
HWC_PATCH="$ROOT/patches/cm14/cm14.1-headless-hwui-disable.patch"
WIFI_PATCH="$ROOT/patches/cm14/cm14.1-biscuit-sta-only-wifi.patch"
EXTRACTOR="$ROOT/scripts/extract-cm14-fireos6-audio-blobs.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for file in \
  frameworks/base/core/java/android/content/pm/PackageParser.java \
  frameworks/base/core/java/android/view/ThreadedRenderer.java \
  frameworks/base/core/java/android/view/ViewRootImpl.java \
  device/amazon/mt8163-common/system.prop \
  device/amazon/mt8163-common/mt8163-common.mk \
  external/wpa_supplicant_8/wpa_supplicant/Android.mk \
  external/wpa_supplicant_8/wpa_supplicant/android.config \
  external/wpa_supplicant_8/wpa_supplicant/ctrl_iface.c \
  frameworks/base/packages/SettingsProvider/res/values/defaults.xml \
  frameworks/opt/net/wifi/service/java/com/android/server/wifi/WifiStateMachine.java; do
  mkdir -p "$WORK/$(dirname "$file")"
  cp "$CM14/$file" "$WORK/$file"
done

apply_from_base() {
  local patch_file="$1"
  if patch --batch --forward --fuzz=0 --dry-run -d "$WORK" -p1 <"$patch_file" >/dev/null; then
    patch --batch --forward --fuzz=0 -d "$WORK" -p1 <"$patch_file" >/dev/null
  else
    patch --batch --forward --fuzz=0 --dry-run -R -d "$WORK" -p1 <"$patch_file" >/dev/null
    patch --batch --forward --fuzz=0 -R -d "$WORK" -p1 <"$patch_file" >/dev/null
    patch --batch --forward --fuzz=0 -d "$WORK" -p1 <"$patch_file" >/dev/null
  fi
}

apply_from_base "$PROP_PATCH"
apply_from_base "$HWC_PATCH"
apply_from_base "$WIFI_PATCH"

for file in \
  frameworks/base/core/java/android/content/pm/PackageParser.java \
  frameworks/base/core/java/android/view/ThreadedRenderer.java \
  frameworks/base/core/java/android/view/ViewRootImpl.java; do
  grep -Fq 'ro.config.no_gpu' "$WORK/$file"
done
grep -Fq '<bool name="def_wifi_on">true</bool>' \
  "$WORK/frameworks/base/packages/SettingsProvider/res/values/defaults.xml"
grep -Fqx '# CONFIG_P2P=y' \
  "$WORK/external/wpa_supplicant_8/wpa_supplicant/android.config"
grep -Fqx '# L_CFLAGS += -DANDROID_P2P' \
  "$WORK/external/wpa_supplicant_8/wpa_supplicant/Android.mk"
! grep -Fq 'android.hardware.wifi.direct.xml:' \
  "$WORK/device/amazon/mt8163-common/mt8163-common.mk"
grep -Fqx 'lib/hw/hwcomposer.mt8163.so:lib/hw/hwcomposer.mt8163.so:ec66527090a97538914a5d883cf5b43013aea69905f29c9e4af490eb8a48e79a:13568' \
  "$HWC_MANIFEST"
grep -Fqx 'ro.config.no_gpu=true' "$WORK/device/amazon/mt8163-common/system.prop"
grep -Fqx 'SYSTEM_PROP="$CM14/device/amazon/mt8163-common/system.prop"' "$STAGE"
grep -Fqx '  echo "Headless system properties already staged."' "$STAGE"
grep -Fqx 'apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-headless-no-gpu-property.patch"' "$STAGE"
grep -Fqx 'apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-headless-hwui-disable.patch"' "$STAGE"
grep -Fqx 'apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-biscuit-sta-only-wifi.patch"' "$STAGE"
grep -Fq 'STOCK_HWC_SYSTEM_SHA256="bd928aa5087b8d8c40095c784dfc159cc2555ed4130d617b258bfd0a06659f7c"' "$EXTRACTOR"
grep -Fq 'HWC_MANIFEST=' "$EXTRACTOR"
bash -n "$EXTRACTOR" "$STAGE"

echo 'PASS CM14 CM12-derived headless display and STA Wi-Fi compatibility'
