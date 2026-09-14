# Minimal Android-shaped userspace for Biscuit.
# Keep this list explicit: framework packages belong in cm_biscuit, not here.

LOCAL_PATH := device/amazon/biscuit
BISCUIT_MINIMAL_INIT_RC ?= $(LOCAL_PATH)/rootdir/init.biscuit.minimal.rc
BISCUIT_INSTALL_LEDCONTROLLER_FALLBACK ?= true

# ponytail: keep the verified Fire OS 6 vendor closure for first minimal bring-up;
# reduce it only after hardware probes identify unused blobs.
$(call inherit-product, vendor/amazon/mt8163-common/mt8163-common-vendor.mk)

PRODUCT_PACKAGES += \
    init \
    init.environ.rc \
    linker \
    libc \
    libcutils \
    libdl \
    liblog \
    libm \
    libnetutils \
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
    toybox \
    grep \
    sepolicy \
    file_contexts \
    property_contexts \
    seapp_contexts \
    service_contexts \
    selinux_version \
    wpa_supplicant \
    wpa_cli \
    wpa_passphrase \
    dhcpcd-6.8.2 \
    libtinyalsa \
    tinymix \
    tinyplay \
    tinycap \
    tinypcminfo \
    iptables \
    ip6tables

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/init.minimal.rc:root/init.rc \
    system/core/rootdir/init.usb.rc:root/init.usb.rc \
    system/core/rootdir/ueventd.rc:root/ueventd.rc \
    system/core/rootdir/etc/hosts:system/etc/hosts \
    $(LOCAL_PATH)/rootdir/fstab.mt8163:root/fstab.mt8163 \
    $(BISCUIT_MINIMAL_INIT_RC):root/init.biscuit.minimal.rc \
    $(LOCAL_PATH)/rootdir/init.biscuit.minimal.usb.rc:root/init.biscuit.minimal.usb.rc \
    device/amazon/mt8163-common/rootdir/etc/init.mt8163.usb.rc:root/init.mt8163.usb.rc \
    device/amazon/mt8163-common/rootdir/etc/ueventd.mt8163.rc:root/ueventd.mt8163.rc \
    external/dhcpcd-6.8.2/dhcpcd.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/dhcpcd/dhcpcd.conf \
    $(LOCAL_PATH)/audio/audio_init.sh:$(TARGET_COPY_OUT_SYSTEM)/etc/audio_init.sh \
    $(LOCAL_PATH)/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/wifi/wpa_supplicant_overlay.conf \
    $(LOCAL_PATH)/rootdir/wifi-bootstrap.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/wifi-bootstrap.sh \
    $(LOCAL_PATH)/rootdir/wpa_connect:$(TARGET_COPY_OUT_SYSTEM)/bin/wpa_connect

ifeq ($(BISCUIT_INSTALL_LEDCONTROLLER_FALLBACK),true)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/ledcontroller:$(TARGET_COPY_OUT_SYSTEM)/bin/ledcontroller
endif

TARGET_BOARD_PLATFORM := mt8163
TARGET_BOOTLOADER_BOARD_NAME := biscuit
WITH_DEXPREOPT := false

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=adb \
    service.adb.tcp.port=5555 \
    wifi.interface=wlan0
