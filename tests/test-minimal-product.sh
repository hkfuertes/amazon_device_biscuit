#!/usr/bin/env bash
# Guard the CM14.1 Biscuit framework-free minimal product contract.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="$ROOT/device/amazon/biscuit"
MINIMAL_MK="$DEVICE/biscuit_minimal.mk"
MINIMAL_DEVICE="$DEVICE/biscuit_minimal_device.mk"
INIT="$DEVICE/rootdir/init.minimal.rc"
HW_INIT="$DEVICE/rootdir/init.biscuit.minimal.rc"
WIFI="$DEVICE/rootdir/wifi-bootstrap.sh"
WPA_CONNECT="$DEVICE/rootdir/wpa_connect"
LED="$DEVICE/rootdir/ledcontroller"

for f in "$MINIMAL_MK" "$MINIMAL_DEVICE" "$INIT" "$HW_INIT" "$WIFI" "$WPA_CONNECT" "$LED"; do
  [[ -f "$f" ]]
done

[[ -x "$WIFI" ]]
[[ -x "$WPA_CONNECT" ]]
[[ -x "$LED" ]]

grep -Fqx '    $(LOCAL_DIR)/biscuit_minimal.mk' "$DEVICE/AndroidProducts.mk"
grep -Fqx 'add_lunch_combo biscuit_minimal-userdebug' "$DEVICE/vendorsetup.sh"
grep -Fqx 'PRODUCT_NAME := biscuit_minimal' "$MINIMAL_MK"
grep -Fqx 'PRODUCT_DEVICE := biscuit' "$MINIMAL_MK"
grep -Fqx 'PRODUCT_MODEL := Echo Dot Minimal Base' "$MINIMAL_MK"
! grep -Fq 'full_base.mk' "$MINIMAL_MK"
! grep -Fq 'vendor/cm/config/common.mk' "$MINIMAL_MK"
! grep -Fq 'device/amazon/biscuit/device.mk' "$MINIMAL_MK"

grep -Fqx '$(call inherit-product, vendor/amazon/mt8163-common/mt8163-common-minimal-vendor.mk)' "$MINIMAL_DEVICE"
grep -Fqx 'TARGET_BISCUIT_MINIMAL := true' "$MINIMAL_DEVICE"
grep -Fqx 'TARGET_DISABLE_CMSDK := true' "$MINIMAL_DEVICE"
grep -Fqx 'WITHOUT_CHECK_API := true' "$MINIMAL_DEVICE"
grep -Fqx '+type exfat, sdcard_type, fs_type, mlstrustedobject;' "$ROOT/patches/minimal/006-sepolicy-exfat-ntfs-types.patch"
grep -Fqx '+type ntfs, sdcard_type, fs_type, mlstrustedobject;' "$ROOT/patches/minimal/006-sepolicy-exfat-ntfs-types.patch"
grep -Fq 'p2p_set_country(p2p, country);' "$ROOT/patches/minimal/004-sta-only-wpa-supplicant.patch"
grep -Fq '+#ifdef CONFIG_P2P' "$ROOT/patches/minimal/004-sta-only-wpa-supplicant.patch"
grep -Fq 'files: $(modules_to_install) \' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
grep -Fq 'tags_to_install += debug' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
grep -Fq 'TARGET_PRODUCT),biscuit_minimal' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
grep -Fq 'RECOVERY_RESOURCE_ZIP :=' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
grep -Fq 'RECOVERY_FROM_BOOT_PATCH :=' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
grep -Fq 'clean-biscuit-minimal-target-out' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
grep -Fq 'biscuit_minimal=true' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
grep -Fq 'info_dict.get("biscuit_minimal", None) == "true"' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
! grep -Fq '$(TARGET_OUT)/xbin' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
grep -Fq '$(TARGET_OUT)/usr/share/vim' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
grep -Fq '$(TARGET_OUT)/lib/libandroid_runtime.so' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
grep -Fq '$(TARGET_OUT)/lib/libLLVM.so' "$ROOT/patches/minimal/007-framework-free-systemimage-trim.patch"
[[ -f "$ROOT/vendor/amazon/mt8163-common/mt8163-common-minimal-vendor.mk" ]]
for pkg in init init.environ.rc adbd sh toolbox toybox logd logcat wpa_supplicant wpa_cli wpa_passphrase dhcpcd-6.8.2 tinymix tinyplay tinycap tinypcminfo i2c-poke biscuit_mic_test bash nano tcpdump fio strace procrank procmem librank latencytop cpustats mmc_utils ksminfo dnschk anrd iptables ip6tables; do
  grep -Eq "^[[:space:]]+$pkg([[:space:]]+\\\\)?[[:space:]]*$" "$MINIMAL_DEVICE"
done
for forbidden in BiscuitService BiscuitEmptyLauncher biscuit-ledd biscuit-ledctl biscuit_service surfaceflinger zygote system_server bootanimation Bluetooth; do
  ! grep -Eq "^[[:space:]]+$forbidden([[:space:]]+\\\\)?[[:space:]]*$" "$MINIMAL_DEVICE"
done

grep -Fqx '    $(LOCAL_PATH)/rootdir/init.minimal.rc:root/init.rc \' "$MINIMAL_DEVICE"
grep -Fqx '    $(BISCUIT_MINIMAL_INIT_RC):root/init.biscuit.minimal.rc \' "$MINIMAL_DEVICE"
grep -Fqx '    $(LOCAL_PATH)/rootdir/wifi-bootstrap.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/wifi-bootstrap.sh \' "$MINIMAL_DEVICE"
grep -Fqx '    $(LOCAL_PATH)/rootdir/wpa_connect:$(TARGET_COPY_OUT_SYSTEM)/bin/wpa_connect' "$MINIMAL_DEVICE"
grep -Fqx '    $(LOCAL_PATH)/rootdir/ledcontroller:$(TARGET_COPY_OUT_SYSTEM)/bin/ledcontroller' "$MINIMAL_DEVICE"

grep -Fqx 'import /init.biscuit.minimal.rc' "$INIT"
grep -Fqx '    setprop sys.boot_completed 1' "$INIT"
grep -Fqx 'on property:sys.powerctl=*' "$INIT"
grep -Fqx 'service adbd /sbin/adbd --root_seclabel=u:r:su:s0' "$INIT"
! grep -Fq 'class_start main' "$INIT"
! grep -Fq 'class_start late_start' "$INIT"

grep -Fqx '    mount_all /fstab.mt8163' "$HW_INIT"
grep -Fqx 'service wmt_loader /vendor/bin/wmt_loader' "$HW_INIT"
grep -Fqx 'service wmt_launcher /vendor/bin/wmt_launcher -p /vendor/firmware/' "$HW_INIT"
grep -Fqx '    chmod 0660 /dev/stpbt' "$HW_INIT"
grep -Fqx '    chown bluetooth bluetooth /dev/stpbt' "$HW_INIT"
grep -Fqx 'service wpa_supplicant /system/bin/wpa_supplicant \' "$HW_INIT"
grep -Fqx 'service dhcpcd_wlan0 /system/bin/dhcpcd-6.8.2 -ABKL -f /system/etc/dhcpcd/dhcpcd.conf wlan0' "$HW_INIT"
grep -Fqx 'service ledcontroller /system/bin/ledcontroller' "$HW_INIT"
! grep -Fq '6620_launcher' "$HW_INIT"

! grep -Fq 'boot_a_x' "$DEVICE/rootdir/fstab.mt8163"
grep -Fq '/dev/block/platform/bootdevice/by-name/system' "$DEVICE/rootdir/fstab.mt8163"
grep -Fq 'slotselect' "$DEVICE/rootdir/fstab.mt8163"

grep -Fqx 'WPA_PASSPHRASE=/system/bin/wpa_passphrase' "$WPA_CONNECT"
! grep -Fq busybox "$WPA_CONNECT"
! grep -Fq awk "$WPA_CONNECT"
! grep -Fq 'tail -n' "$WPA_CONNECT"
grep -Fq '# No saved network after a wipe: keep wpa_supplicant alive for provisioning.' "$WIFI"
! grep -Fq awk "$WIFI"
! grep -Fq busybox "$WIFI"

grep -Fq 'boot_animation' "$LED"
grep -Fq 'LED ring did not become ready' "$LED"
grep -Fq 'exec /system/bin/sleep 2147483647' "$LED"

echo 'PASS CM14 minimal product contract'
