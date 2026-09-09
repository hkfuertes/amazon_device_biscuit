#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT="$ROOT/device/amazon/biscuit/biscuit_bootstrap.mk"
DEVICE="$ROOT/device/amazon/biscuit/biscuit_bootstrap_device.mk"
INIT="$ROOT/device/amazon/biscuit/rootdir/init.biscuit.bootstrap.rc"
ROOT_INIT="$ROOT/device/amazon/biscuit/rootdir/init.bootstrap.rc"
WIFI_BOOTSTRAP="$ROOT/device/amazon/biscuit/rootdir/wifi-bootstrap.sh"
LEDCONTROLLER="$ROOT/device/amazon/biscuit/rootdir/ledcontroller"
BUILD="$ROOT/scripts/build.sh"

for file in "$PRODUCT" "$DEVICE" "$INIT" "$ROOT_INIT" "$WIFI_BOOTSTRAP" "$LEDCONTROLLER" "$BUILD"; do
  [[ -f "$file" ]] || { echo "missing: $file" >&2; exit 1; }
done

! grep -Eq 'inherit-product.*(full_base|core_minimal|core_tiny|vendor/cm/config/common)' "$PRODUCT" "$DEVICE"
grep -Fq 'PRODUCT_NAME         := biscuit_bootstrap' "$PRODUCT"
grep -Fq "rm -rf '\$OUT_DIR/target/product/biscuit'" "$BUILD"
! grep -Fq "'\$OUT_DIR/target/product/biscuit/system'" "$BUILD"
! grep -Fqi 'echolocal' "$PRODUCT" "$INIT"
grep -Fq 'wpa_supplicant' "$DEVICE"
grep -Fq 'dhcpcd' "$DEVICE"
grep -Fq 'tinymix' "$DEVICE"
for package in linker linker64 libc libcutils libdl liblog libm libstdc++ libsigchain mkshrc reboot logwrapper logd logcat; do
    grep -Fq "    $package \\" "$DEVICE"
done
grep -Fq '    init.environ.rc \' "$DEVICE"
! grep -Fq 'init.environ.rc:root/init.environ.rc' "$DEVICE"
grep -Fq 'system/core/rootdir/init.usb.rc:root/init.usb.rc' "$DEVICE"
grep -Fq 'system/core/rootdir/ueventd.rc:root/ueventd.rc' "$DEVICE"
grep -Fq 'system/core/rootdir/etc/hosts:system/etc/hosts' "$DEVICE"
grep -Fq 'external/dhcpcd/android.conf:system/etc/dhcpcd/dhcpcd.conf' "$DEVICE"
grep -Fq 'LIBART_IMG_HOST_BASE_ADDRESS := 0x60000000' "$DEVICE"
grep -Fq 'LIBART_IMG_TARGET_BASE_ADDRESS := 0x70000000' "$DEVICE"
grep -Fq 'WITH_DEXPREOPT := false' "$DEVICE"
! grep -Fq 'service echod' "$INIT"
! grep -Fq 'service biscuit-ledd' "$INIT"
grep -Fq 'on property:sys.powerctl=*' "$ROOT_INIT"
grep -Fq 'powerctl ${sys.powerctl}' "$ROOT_INIT"
grep -Fq 'on load_all_props_action' "$ROOT_INIT"
grep -Fq 'load_all_props' "$ROOT_INIT"
grep -Fq 'trigger firmware_mounts_complete' "$ROOT_INIT"
grep -Fq 'trigger early-boot' "$ROOT_INIT"
for line in \
    'setcon u:r:init:s0' \
    'symlink /system/etc /etc' \
    'symlink /system/vendor /vendor' \
    'mount cgroup none /dev/cpuctl cpu' \
    'mkdir /dev/cpuctl/bg_non_interactive' \
    'chown system system /data' \
    'chmod 0771 /data' \
    'restorecon /data' \
    'mkdir /tmp 0771 root root' \
    'mkdir /data/misc 01771 system misc' \
    'mkdir /data/local/tmp 0771 shell shell' \
    'mkdir /data/property 0700 root root' \
    'ifup lo' \
    'hostname localhost' \
    'domainname localdomain' \
    'class_start core' \
    'service logd /system/bin/logd' \
    'socket logd stream 0666 logd logd' \
    'socket logdr seqpacket 0666 logd logd' \
    'socket logdw dgram 0222 logd logd' \
    'seclabel u:r:logd:s0'; do
    grep -Fq "$line" "$ROOT_INIT"
done
# Persistent properties must be loaded after their directory exists.
awk '/mkdir \/data\/property / { directory = 1 }
     /load_persist_props/ { if (!directory) exit 1; loaded = 1 }
     END { if (!loaded) exit 1 }' "$ROOT_INIT"
awk '
    $0 == "on property:ro.product.device=biscuit" { in_handler = 1; next }
    /^on |^service / { in_handler = 0 }
    in_handler && $0 ~ /^[[:space:]]*start wmtLoader$/ { wmt = 1 }
    in_handler && $0 ~ /^[[:space:]]*start conn_launcher$/ { conn = 1 }
    END { exit !(wmt && conn) }
' "$INIT"
awk '
    $0 == "on post-fs-data" { in_post_fs_data = 1; next }
    /^on |^service / { in_post_fs_data = 0 }
    in_post_fs_data && $0 ~ /^[[:space:]]*start (wmtLoader|conn_launcher)$/ { found = 1 }
    END { exit found }
' "$INIT"
# Imported hardware actions are parsed before root init actions: make their parent explicit.
awk '
    $0 == "on post-fs-data" { in_post_fs_data = 1; next }
    /^on |^service / { in_post_fs_data = 0 }
    in_post_fs_data && $0 == "    mkdir /data/misc 01771 system misc" { parent = 1 }
    in_post_fs_data && $0 == "    mkdir /data/misc/wifi 0770 wifi wifi" {
        if (!parent) exit 1
        child = 1
    }
    END { exit !(parent && child) }
' "$INIT"
grep -Fq 'BISCUIT_BOOTSTRAP_INIT_RC ?= $(LOCAL_PATH)/rootdir/init.biscuit.bootstrap.rc' "$DEVICE"
grep -Fq 'BISCUIT_INSTALL_LEDCONTROLLER_FALLBACK ?= true' "$DEVICE"
grep -Fq '$(BISCUIT_BOOTSTRAP_INIT_RC):root/init.biscuit.bootstrap.rc' "$DEVICE"
grep -Fq 'ifeq ($(BISCUIT_INSTALL_LEDCONTROLLER_FALLBACK),true)' "$DEVICE"
grep -Fq '$(LOCAL_PATH)/rootdir/ledcontroller:system/bin/ledcontroller' "$DEVICE"
grep -Fq '    start ledcontroller' "$INIT"
grep -Fq 'service ledcontroller /system/bin/ledcontroller' "$INIT"
awk '
    /^service ledcontroller / { in_service = 1; seen = 1; next }
    in_service && /^(service |on )/ { in_service = 0 }
    in_service && /^[[:space:]]*oneshot$/ { bad = 1 }
    END { exit !(seen && !bad) }
' "$INIT"
grep -Fq 'without consuming CPU' "$LEDCONTROLLER"
grep -Fq 'without modifying boot.img or the ramdisk' "$LEDCONTROLLER"
grep -Fq 'exec /system/bin/sleep 2147483647' "$LEDCONTROLLER"
[[ -x "$LEDCONTROLLER" ]]
grep -Fq 'chown wifi:wifi "$config"' "$WIFI_BOOTSTRAP"
grep -Fq 'radio_settle_seconds=5' "$WIFI_BOOTSTRAP"
grep -Fq 'sleep "$radio_settle_seconds"' "$WIFI_BOOTSTRAP"
grep -Fq 'until /system/bin/wpa_cli -iwlan0 -p/data/misc/wifi/sockets scan' "$WIFI_BOOTSTRAP"
grep -Fq "wpa_state=COMPLETED" "$WIFI_BOOTSTRAP"
grep -Fq 'setprop ctl.restart dhcpcd_wlan0' "$WIFI_BOOTSTRAP"
[[ -x "$WIFI_BOOTSTRAP" ]]
grep -Fq '/sys/bus/i2c/devices/0-003f/boot_animation' "$LEDCONTROLLER"
grep -Fq '/sys/bus/i2c/devices/0-003f/frame' "$LEDCONTROLLER"
grep -Fq "printf '%s' \"\$green\" > \"\$frame\"" "$LEDCONTROLLER"
grep -Fq "printf '%s' \"\$black\" > \"\$frame\"" "$LEDCONTROLLER"
! grep -Fq 'led_bootstrap' "$DEVICE" "$INIT"
! grep -Fq 'biscuit-ledd' "$DEVICE" "$INIT" "$LEDCONTROLLER"
grep -Fq 'service wifi_events /system/bin/wpa_cli -iwlan0 -p/data/misc/wifi/sockets -a/system/bin/wifi-bootstrap.sh' "$INIT"
grep -Fq '    -iwlan0 -Dnl80211' "$INIT"
# Android wpa_supplicant preserves NET_ADMIN/NET_RAW only when init starts it as root.
awk '
    /^service wpa_supplicant / { in_wpa = 1; seen = 1; next }
    in_wpa && /^(service |on )/ { in_wpa = 0 }
    in_wpa && (/^[[:space:]]*-W([[:space:]]|$)/ || /^[[:space:]]*user wifi$/ || /^[[:space:]]*group wifi inet keystore$/) { bad = 1 }
    END { exit !(seen && !bad) }
' "$INIT"
grep -Fq 'on property:init.svc.wpa_supplicant=running' "$INIT"
grep -Fq '    start wifi_events' "$INIT"
grep -Fq '    stop wifi_events' "$INIT"
grep -Fq 'service dhcpcd_wlan0 /system/bin/dhcpcd -ABKL -f /system/etc/dhcpcd/dhcpcd.conf wlan0' "$INIT"
# DHCP is controlled by association events, not merely by powering the radio.
! grep -Eq '^[[:space:]]*start dhcpcd_wlan0$' "$INIT"

echo 'bootstrap product static checks passed'
