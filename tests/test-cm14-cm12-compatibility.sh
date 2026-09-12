#!/usr/bin/env bash
# Verify CM12-derived headless display and STA-only Wi-Fi compatibility patches.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM14="${CM14:-$ROOT/workspace/cm14.1}"
STAGE="$ROOT/scripts/stage-cm14.1-tree.sh"
HWC_MANIFEST="$ROOT/cm14.1/vendor/amazon/mt8163-common/biscuit-headless-hwc-files.txt"
RADIO_MANIFEST="$ROOT/cm14.1/vendor/amazon/mt8163-common/biscuit-radio-files.txt"
PROP_PATCH="$ROOT/patches/cm14/cm14.1-headless-no-gpu-property.patch"
HWC_PATCH="$ROOT/patches/cm14/cm14.1-headless-hwui-disable.patch"
HWC1_PATCH="$ROOT/patches/cm14/cm14.1-headless-hwc1-fake-display.patch"
RADIO_PATCH="$ROOT/patches/cm14/cm14.1-biscuit-radio-launchers.patch"
WIFI_PATCH="$ROOT/patches/cm14/cm14.1-biscuit-sta-only-wifi.patch"
LOG_PATCH="$ROOT/patches/cm14/cm14.1-amazon-log-shim.patch"
EXTRACTOR="$ROOT/scripts/extract-cm14-fireos6-audio-blobs.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for file in \
  system/core/liblog/logger_write.c \
  frameworks/native/services/surfaceflinger/DisplayHardware/HWComposer_hwc1.cpp \
  frameworks/base/core/java/android/content/pm/PackageParser.java \
  frameworks/base/core/java/android/view/ThreadedRenderer.java \
  frameworks/base/core/java/android/view/ViewRootImpl.java \
  device/amazon/mt8163-common/system.prop \
  device/amazon/mt8163-common/mt8163-common.mk \
  device/amazon/mt8163-common/rootdir/etc/init.mt8163.rc \
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

apply_from_base "$LOG_PATCH"
apply_from_base "$PROP_PATCH"
apply_from_base "$HWC_PATCH"
apply_from_base "$HWC1_PATCH"
apply_from_base "$RADIO_PATCH"
apply_from_base "$WIFI_PATCH"

grep -Fqx '        ALOGW("No framebuffer; using Biscuit headless fake primary display");' \
  "$WORK/frameworks/native/services/surfaceflinger/DisplayHardware/HWComposer_hwc1.cpp"
grep -Fqx 'service conn_launcher /system/bin/6620_launcher -p /system/etc/firmware/' \
  "$WORK/device/amazon/mt8163-common/rootdir/etc/init.mt8163.rc"
grep -Fqx '    start wmtLoader' "$WORK/device/amazon/mt8163-common/rootdir/etc/init.mt8163.rc"

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
grep -Fqx 'bin/wmt_loader:bin/wmt_loader:ecbb5934f7a9ffebb5e8bafc2a227c3369308b8eb548888b79d1ad6e54694590:9696' \
  "$RADIO_MANIFEST"
grep -Fqx 'etc/wifi/wpa_supplicant.conf:etc/wifi/wpa_supplicant.conf:119857c7f3e5dedff458c82810806f133d19621d128c2c564966b577631d9604:305' \
  "$RADIO_MANIFEST"
grep -Fqx 'LIBLOG_ABI_PUBLIC int lab126_log_write(int prio, const char *tag,' \
  "$WORK/system/core/liblog/logger_write.c"
grep -Fqx 'ro.config.no_gpu=true' "$WORK/device/amazon/mt8163-common/system.prop"
grep -Fqx 'LIBLOG_WRITE="$CM14/system/core/liblog/logger_write.c"' "$STAGE"
grep -Fqx '  echo "Amazon liblog shim already staged."' "$STAGE"
grep -Fqx '  apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-amazon-log-shim.patch"' "$STAGE"
grep -Fqx 'SYSTEM_PROP="$CM14/device/amazon/mt8163-common/system.prop"' "$STAGE"
grep -Fqx '  echo "Headless system properties already staged."' "$STAGE"
grep -Fqx '  echo "Headless no-GPU property already staged."' "$STAGE"
grep -Fqx '  apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-headless-no-gpu-property.patch"' "$STAGE"
grep -Fqx 'apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-headless-hwui-disable.patch"' "$STAGE"
grep -Fqx 'HWC1="$CM14/frameworks/native/services/surfaceflinger/DisplayHardware/HWComposer_hwc1.cpp"' "$STAGE"
grep -Fqx '  echo "Headless HWC1 fake display already staged."' "$STAGE"
grep -Fqx '  apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-headless-hwc1-fake-display.patch"' "$STAGE"
grep -Fqx 'MT8163_INIT="$CM14/device/amazon/mt8163-common/rootdir/etc/init.mt8163.rc"' "$STAGE"
grep -Fqx '  echo "Biscuit radio launchers already staged."' "$STAGE"
grep -Fqx '  apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-biscuit-radio-launchers.patch"' "$STAGE"
grep -Fqx 'apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-biscuit-sta-only-wifi.patch"' "$STAGE"
grep -Fq 'STOCK_HWC_SYSTEM_SHA256="bd928aa5087b8d8c40095c784dfc159cc2555ed4130d617b258bfd0a06659f7c"' "$EXTRACTOR"
grep -Fq 'HWC_MANIFEST=' "$EXTRACTOR"
grep -Fq 'RADIO_MANIFEST=' "$EXTRACTOR"
grep -Fq '[[ "$radio_count" == 14 ]]' "$EXTRACTOR"
grep -Fq 'mode=0755' "$EXTRACTOR"
bash -n "$EXTRACTOR" "$STAGE"

echo 'PASS CM14 CM12-derived headless display and STA Wi-Fi compatibility'
