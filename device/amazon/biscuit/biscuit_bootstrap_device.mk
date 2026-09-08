# Minimal Android-shaped userspace for Biscuit.
# Keep this list explicit: framework packages belong in cm_biscuit, not here.

LOCAL_PATH := device/amazon/biscuit

# ponytail: preserve the opaque vendor closure for the first hardware boot; reduce it only after
# audio, Wi-Fi, and HCI probes identify the blobs actually used.
$(call inherit-product, vendor/amazon/mt8163-common/mt8163-common-vendor.mk)
$(call inherit-product-if-exists, vendor/amazon/biscuit/biscuit-vendor.mk)

# Explicit non-framework runtime subset from embedded.mk.
PRODUCT_PACKAGES += \
    init \
    init.environ.rc \
    linker \
    linker64 \
    libc \
    libcutils \
    libdl \
    liblog \
    libm \
    libstdc++ \
    libsigchain \
    adbd \
    mkshrc \
    reboot \
    logwrapper \
    logd \
    logcat \
    sh \
    toolbox \
    sepolicy \
    file_contexts \
    property_contexts \
    seapp_contexts \
    service_contexts \
    selinux_version \
    wpa_supplicant \
    wpa_cli \
    dhcpcd \
    dhcpcd-run-hooks \
    20-dns.conf \
    95-configured \
    tinymix \
    iptables \
    ip6tables

# Reuse the general CM12 device rules as well as the MT8163-specific rules.
# Native hardware access needs no AudioFlinger, Bluetooth APK, or Java framework.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/init.bootstrap.rc:root/init.rc \
    system/core/rootdir/init.usb.rc:root/init.usb.rc \
    system/core/rootdir/ueventd.rc:root/ueventd.rc \
    system/core/rootdir/etc/hosts:system/etc/hosts \
    external/dhcpcd/android.conf:system/etc/dhcpcd/dhcpcd.conf \
    $(LOCAL_PATH)/rootdir/fstab.mt8163:root/fstab.mt8163 \
    $(LOCAL_PATH)/rootdir/init.biscuit.bootstrap.rc:root/init.biscuit.bootstrap.rc \
    $(LOCAL_PATH)/rootdir/init.biscuit.usb.rc:root/init.biscuit.usb.rc \
    device/amazon/mt8163-common/rootdir/etc/init.mt8163.usb.rc:root/init.mt8163.usb.rc \
    device/amazon/mt8163-common/rootdir/etc/ueventd.mt8163.rc:root/ueventd.mt8163.rc \
    $(LOCAL_PATH)/rootdir/wifi-bootstrap.sh:system/bin/wifi-bootstrap.sh \
    $(LOCAL_PATH)/rootdir/led-bootstrap.sh:system/bin/led-bootstrap.sh \
    $(LOCAL_PATH)/cacerts.pem:system/etc/security/cacerts.pem

TARGET_BOARD_PLATFORM := mt8163
TARGET_BOOTLOADER_BOARD_NAME := biscuit

# Android 5.1 parses ART rules globally even when this image installs no Java runtime.
LIBART_IMG_HOST_BASE_ADDRESS := 0x60000000
LIBART_IMG_TARGET_BASE_ADDRESS := 0x70000000
WITH_DEXPREOPT := false

# ponytail: root ADB is intentional for this development base; harden before release.
ADDITIONAL_DEFAULT_PROPERTIES += \
    ro.adb.secure=0 \
    ro.secure=0 \
    ro.debuggable=1 \
    service.adb.root=1
