#!/usr/bin/env bash
# Assert the framework-free EchoLocal product contract without an Android build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT="$ROOT/device/amazon/biscuit/biscuit_echolocal.mk"
DEVICE="$ROOT/device/amazon/biscuit/biscuit_bootstrap_device.mk"
PRODUCTS="$ROOT/device/amazon/biscuit/AndroidProducts.mk"
MODULE="$ROOT/device/amazon/biscuit/echolocal/Android.mk"
INIT="$ROOT/device/amazon/biscuit/rootdir/init.biscuit.echolocal.rc"
COMMON="$ROOT/device/amazon/biscuit/rootdir/init.biscuit.common.rc"
BOOTSTRAP="$ROOT/device/amazon/biscuit/rootdir/echolocal-bootstrap.sh"
CONTROL="$ROOT/device/amazon/biscuit/rootdir/echolocal.sh"
START="$ROOT/device/amazon/biscuit/rootdir/start_animation.sh"
STOP="$ROOT/device/amazon/biscuit/rootdir/stop_animation.sh"

for file in "$PRODUCT" "$DEVICE" "$PRODUCTS" "$MODULE" "$INIT" "$COMMON" "$BOOTSTRAP" "$CONTROL" "$START" "$STOP"; do
    [[ -f "$file" ]] || { echo "missing: $file" >&2; exit 1; }
done

grep -Fq '$(LOCAL_DIR)/biscuit_echolocal.mk' "$PRODUCTS"
grep -Fq 'BISCUIT_BOOTSTRAP_INIT_RC := device/amazon/biscuit/rootdir/init.biscuit.echolocal.rc' "$PRODUCT"
! grep -Fq 'BISCUIT_ENABLE_LED_BOOTSTRAP' "$PRODUCT"
grep -Fq 'BISCUIT_ENABLE_LED_BOOTSTRAP ?= true' "$DEVICE"
grep -Fq '$(LOCAL_PATH)/rootdir/led-bootstrap.sh:system/bin/led-bootstrap.sh' "$DEVICE"
grep -Fq 'PRODUCT_NAME         := biscuit_echolocal' "$PRODUCT"
grep -Fq 'PRODUCT_MODEL        := Echo Dot' "$PRODUCT"
! grep -Eq 'inherit-product.*(full_base|core_minimal|core_tiny|vendor/cm/config/common)' "$PRODUCT"
grep -Fq 'PRODUCT_PACKAGES += \' "$PRODUCT"
grep -Fq '    echod \' "$PRODUCT"
grep -Fq '    busybox' "$PRODUCT"
! grep -Fq 'wpa_passphrase' "$PRODUCT"
grep -Fq '$(LOCAL_PATH)/rootdir/echolocal.sh:system/bin/echolocal' "$PRODUCT"
grep -Fq '$(LOCAL_PATH)/rootdir/echolocal-bootstrap.sh:system/bin/echolocal-bootstrap.sh' "$PRODUCT"
grep -Fq '$(LOCAL_PATH)/rootdir/start_animation.sh:system/bin/start_animation.sh' "$PRODUCT"
grep -Fq '$(LOCAL_PATH)/rootdir/stop_animation.sh:system/bin/stop_animation.sh' "$PRODUCT"
for model in okay_nabu hey_jarvis hey_mycroft; do
    grep -Fq "\$(LOCAL_PATH)/echolocal/models/$model.json:system/etc/echolocal/models/$model.json" "$PRODUCT"
    grep -Fq "\$(LOCAL_PATH)/echolocal/models/$model.tflite:system/etc/echolocal/models/$model.tflite" "$PRODUCT"
done

grep -Fq 'LOCAL_MODULE := echod' "$MODULE"
grep -Fq 'LOCAL_MODULE_CLASS := EXECUTABLES' "$MODULE"
grep -Fq 'LOCAL_MODULE_PATH := $(TARGET_OUT)/app/echod' "$MODULE"
grep -Fq 'chmod 0755 $(TARGET_OUT)/app/echod/echod' "$MODULE"
grep -Fq 'ln -sf /system/app/echod/echod $(TARGET_OUT_EXECUTABLES)/ledcontroller' "$MODULE"
grep -Fq 'import /init.biscuit.common.rc' "$INIT"
grep -Fq 'mkdir /data/misc/echolocal 0770 root system' "$INIT"
grep -Fq 'mkdir /data/misc/echolocal/models 0770 root system' "$INIT"
grep -Fq 'start echolocal-boot' "$INIT"
grep -Fq 'service echolocal-boot /system/bin/logwrapper /system/bin/sh /system/bin/echolocal-bootstrap.sh' "$INIT"
! grep -Fq 'echolocal_bootstrap' "$INIT"
grep -Fq 'service ledcontroller /system/bin/ledcontroller' "$INIT"
grep -Fq '    start led_bootstrap' "$INIT"
grep -Fq 'service led_bootstrap /system/bin/sh /system/bin/led-bootstrap.sh' "$INIT"
awk '
    /^service led_bootstrap / { in_service = 1; seen = 1; next }
    in_service && /^(service |on )/ { in_service = 0 }
    in_service && /^[[:space:]]*oneshot$/ { oneshot = 1 }
    END { exit !(seen && oneshot) }
' "$INIT"
! grep -Fqi 'firewall' "$PRODUCT" "$INIT" "$BOOTSTRAP" "$CONTROL"
awk '
    /^service ledcontroller / { in_service = 1; seen = 1; next }
    in_service && /^(service |on )/ { in_service = 0 }
    in_service && /^[[:space:]]*(oneshot|disabled)$/ { bad = 1 }
    END { exit !(seen && !bad) }
' "$INIT"

grep -Fq '/system/bin/start_animation.sh' "$BOOTSTRAP"
grep -Fq '/system/bin/echolocal key ensure' "$BOOTSTRAP"
grep -Fq 'setprop ctl.start ledcontroller' "$BOOTSTRAP"
grep -Fq 'if [ ! -f "$models/$model.tflite" ]; then' "$BOOTSTRAP"
grep -Fq 'cp "$seed/$model.json" "$models/$model.json"' "$BOOTSTRAP"
grep -Fq 'cp "$seed/$model.tflite" "$models/$model.tflite"' "$BOOTSTRAP"
grep -Fq 'echolocal key show|rotate' "$CONTROL"
grep -Fq 'echolocal wifi status' "$CONTROL"
grep -Fq 'echolocal wifi connect <ssid>' "$CONTROL"
grep -Fq 'echolocal wifi open <ssid>' "$CONTROL"
grep -Fq 'prepare_wpa_credential' "$CONTROL"
! grep -Fq 'wpa_passphrase' "$CONTROL"
[[ -x "$BOOTSTRAP" && -x "$CONTROL" && -x "$START" && -x "$STOP" ]]

echo 'EchoLocal product static checks passed'
