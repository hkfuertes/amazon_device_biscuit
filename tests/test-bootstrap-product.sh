#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT="$ROOT/device/amazon/biscuit/biscuit_bootstrap.mk"
DEVICE="$ROOT/device/amazon/biscuit/biscuit_bootstrap_device.mk"
INIT="$ROOT/device/amazon/biscuit/rootdir/init.biscuit.bootstrap.rc"
ROOT_INIT="$ROOT/device/amazon/biscuit/rootdir/init.bootstrap.rc"
WIFI_BOOTSTRAP="$ROOT/device/amazon/biscuit/rootdir/wifi-bootstrap.sh"

for file in "$PRODUCT" "$DEVICE" "$INIT" "$ROOT_INIT" "$WIFI_BOOTSTRAP"; do
  [[ -f "$file" ]] || { echo "missing: $file" >&2; exit 1; }
done

! grep -Eq 'inherit-product.*(full_base|core_minimal|core_tiny|vendor/cm/config/common)' "$PRODUCT" "$DEVICE"
grep -Fq 'PRODUCT_NAME         := biscuit_bootstrap' "$PRODUCT"
! grep -Fqi 'echolocal' "$PRODUCT" "$INIT"
grep -Fq 'wpa_supplicant' "$DEVICE"
grep -Fq 'dhcpcd' "$DEVICE"
grep -Fq 'tinymix' "$DEVICE"
for package in linker linker64 libc libcutils libdl liblog libm libstdc++ libsigchain mkshrc reboot logwrapper; do
    grep -Fq "    $package \\" "$DEVICE"
done
grep -Fq '    init.environ.rc \' "$DEVICE"
! grep -Fq 'init.environ.rc:root/init.environ.rc' "$DEVICE"
grep -Fq 'system/core/rootdir/init.usb.rc:root/init.usb.rc' "$DEVICE"
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
grep -Fq 'mkdir /tmp 0771 root root' "$INIT"
grep -Fq 'mkdir /data/misc 01771 system misc' "$INIT"
grep -Fq 'mkdir /data/local/tmp 0771 shell shell' "$INIT"
grep -Fq 'mkdir /data/property 0700 root root' "$INIT"
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
grep -Fq 'chown wifi:wifi "$config"' "$WIFI_BOOTSTRAP"

echo 'bootstrap product static checks passed'
