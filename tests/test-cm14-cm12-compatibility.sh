#!/usr/bin/env bash
# Verify CM12-derived headless display and STA-only Wi-Fi compatibility patches.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM14="${CM14:-$ROOT/workspace/cm14.1}"
STAGE="$ROOT/scripts/stage-cm14.1-tree.sh"
BUILD_SCRIPT="$ROOT/scripts/build-cm14.1.sh"
HWC_MANIFEST="$ROOT/cm14.1/vendor/amazon/mt8163-common/biscuit-headless-hwc-files.txt"
RADIO_MANIFEST="$ROOT/cm14.1/vendor/amazon/mt8163-common/biscuit-radio-files.txt"
BT_MANIFEST="$ROOT/cm14.1/vendor/amazon/mt8163-common/biscuit-bluetooth-files.txt"
PROP_PATCH="$ROOT/patches/cm14/cm14.1-headless-no-gpu-property.patch"
WIFI_IFACE_PATCH="$ROOT/patches/cm14/cm14.1-mt8163-wifi-interface-property.patch"
HWC_PATCH="$ROOT/patches/cm14/cm14.1-headless-hwui-disable.patch"
HWC1_PATCH="$ROOT/patches/cm14/cm14.1-headless-hwc1-fake-display.patch"
RADIO_PATCH="$ROOT/patches/cm14/cm14.1-biscuit-radio-launchers.patch"
WIFI_PATCH="$ROOT/patches/cm14/cm14.1-biscuit-sta-only-wifi.patch"
P2P_PATCH="$ROOT/patches/cm14/cm14.1-biscuit-disable-framework-p2p.patch"
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
  frameworks/opt/net/wifi/service/java/com/android/server/wifi/WifiStateMachine.java \
  frameworks/opt/net/wifi/service/java/com/android/server/wifi/p2p/WifiP2pServiceImpl.java; do
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
apply_from_base "$WIFI_IFACE_PATCH"
apply_from_base "$HWC_PATCH"
apply_from_base "$HWC1_PATCH"
apply_from_base "$RADIO_PATCH"
apply_from_base "$WIFI_PATCH"
apply_from_base "$P2P_PATCH"

grep -Fqx '        ALOGW("No framebuffer; using Biscuit headless fake primary display");' \
  "$WORK/frameworks/native/services/surfaceflinger/DisplayHardware/HWComposer_hwc1.cpp"
grep -Fqx 'service wmt_launcher /vendor/bin/wmt_launcher -p /vendor/firmware/' \
  "$WORK/device/amazon/mt8163-common/rootdir/etc/init.mt8163.rc"
grep -Fqx '    start wmt_launcher' "$WORK/device/amazon/mt8163-common/rootdir/etc/init.mt8163.rc"
grep -Fqx '        if ("biscuit".equals(SystemProperties.get("ro.product.device"))) {' \
  "$WORK/frameworks/opt/net/wifi/service/java/com/android/server/wifi/WifiStateMachine.java"
grep -Fqx '        if ("biscuit".equals(SystemProperties.get("ro.product.device"))) {' \
  "$WORK/frameworks/opt/net/wifi/service/java/com/android/server/wifi/p2p/WifiP2pServiceImpl.java"

for file in \
  frameworks/base/core/java/android/content/pm/PackageParser.java \
  frameworks/base/core/java/android/view/ThreadedRenderer.java \
  frameworks/base/core/java/android/view/ViewRootImpl.java; do
  grep -Fq 'ro.config.no_gpu' "$WORK/$file"
done
grep -Fqx 'wifi.interface=wlan0' \
  "$WORK/device/amazon/mt8163-common/system.prop"
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
grep -Fqx 'system/vendor/bin/wmt_loader:vendor/bin/wmt_loader:de9ee285a09a7db5b079233f7c9129c5484ecb6701b54da45e2a29f310e74ff9:17992' \
  "$RADIO_MANIFEST"
grep -Fqx 'system/vendor/bin/wmt_launcher:vendor/bin/wmt_launcher:1f34425d727ea64524c9edaeac5e6b295df7a6054703dcc79b164021560252e5:31448' \
  "$RADIO_MANIFEST"
grep -Fqx 'system/etc/wifi/wpa_supplicant.conf:etc/wifi/wpa_supplicant.conf:3559d1767cb6e3f0ad55230690476e01c892dbe5c9f4edcda8dea8de7ddb1fd2:118' \
  "$RADIO_MANIFEST"
grep -Fqx 'system/vendor/lib/libbt-vendor.so:vendor/lib/libbt-vendor.so:aab202280e09941a812983c7b7fb259fcb48bf43912f05f8cf7e47e32380ec87:13844' \
  "$BT_MANIFEST"
grep -Fqx 'system/vendor/lib/libbluetooth_mtk.so:vendor/lib/libbluetooth_mtk.so:12e24abe8fcaaf9423fa143e432165b6877fab88222d8de55305bfeb364bdaa0:30268' \
  "$BT_MANIFEST"
grep -Fqx '# ponytail: CM14 Biscuit uses STA only; P2P-only fields make STA-only wpa_supplicant abort.' \
  "$ROOT/cm14.1/device/amazon/biscuit/wpa_supplicant_overlay.conf"
! grep -Fq 'p2p_no_group_iface' "$ROOT/cm14.1/device/amazon/biscuit/wpa_supplicant_overlay.conf"
grep -Fqx '    device/amazon/biscuit/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/wifi/wpa_supplicant_overlay.conf' \
  "$ROOT/cm14.1/device/amazon/biscuit/device.mk"
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
grep -Fqx '  echo "Removed obsolete 64-bit Biscuit radio launchers."' "$STAGE"
grep -Fqx '  echo "Fire OS 6 Biscuit radio launchers already staged."' "$STAGE"
grep -Fqx '  apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-biscuit-radio-launchers.patch"' "$STAGE"
grep -Fqx 'apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-biscuit-sta-only-wifi.patch"' "$STAGE"
grep -Fqx 'WIFI_STATE_MACHINE="$CM14/frameworks/opt/net/wifi/service/java/com/android/server/wifi/WifiStateMachine.java"' "$STAGE"
grep -Fqx '  echo "MT8163 Wi-Fi interface property already staged."' "$STAGE"
grep -Fqx '  echo "Biscuit framework P2P disable already staged."' "$STAGE"
grep -Fqx '  apply_patch "$CM14" 1 "$REPO_ROOT/patches/cm14/cm14.1-biscuit-disable-framework-p2p.patch"' "$STAGE"
grep -Fq 'incremental Android builds do not delete files removed from PRODUCT_COPY_FILES' "$BUILD_SCRIPT"
grep -Fq 'system/bin/6620_launcher' "$BUILD_SCRIPT"
grep -Fq 'system/lib64/libc.so' "$BUILD_SCRIPT"
grep -Fq 'system/etc/firmware/WIFI_RAM_CODE_8163' "$BUILD_SCRIPT"
grep -Fq 'STOCK_HWC_SYSTEM_SHA256="bd928aa5087b8d8c40095c784dfc159cc2555ed4130d617b258bfd0a06659f7c"' "$EXTRACTOR"
grep -Fq 'HWC_MANIFEST=' "$EXTRACTOR"
grep -Fq 'RADIO_MANIFEST=' "$EXTRACTOR"
grep -Fq 'BT_MANIFEST=' "$EXTRACTOR"
grep -Fq 'extract_file "$SYSTEM_IMG" "$source" "$destination" "$expected_sha" "$expected_size"' "$EXTRACTOR"
grep -Fq '[[ "$radio_count" == 7 ]]' "$EXTRACTOR"
grep -Fq '[[ "$bt_count" == 2 ]]' "$EXTRACTOR"
grep -Fq 'bin/*|vendor/bin/*) mode=0755 ;;' "$EXTRACTOR"
bash -n "$EXTRACTOR" "$STAGE"

echo 'PASS CM14 CM12-derived headless display and STA Wi-Fi compatibility'
