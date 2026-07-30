# device.mk — Biscuit-specific packages and properties
# Minimum required to advance to boot-image build.
# Extend in subsequent issues (WiFi, audio, blobs).

LOCAL_PATH := device/amazon/biscuit

# ponytail: common supplies MT8163 display props/rootdir package defaults; Biscuit keeps local ramdisk/blobs below.
$(call inherit-product, device/amazon/mt8163-common/mt8163-common.mk)
$(call inherit-product-if-exists, vendor/amazon/biscuit/biscuit-vendor.mk)

# ── Device characteristics ──────────────────────────────────────────────────
# Headless device: no display, no telephony, no sdcard.
PRODUCT_CHARACTERISTICS := nosdcard

# ── Headless HOME / setup ───────────────────────────────────────────────────
# ponytail: no screen/account flow or Trebuchet DB on Echo; one black HOME is enough.
PRODUCT_PACKAGES := $(filter-out CyanogenSetupWizard SetupWizard Trebuchet Launcher2 Launcher3,$(PRODUCT_PACKAGES))
PRODUCT_PACKAGES += BiscuitEmptyLauncher

# ── HTTPS tools ─────────────────────────────────────────────────────────────
PRODUCT_PACKAGES += \
    curl

# ── Overlays ────────────────────────────────────────────────────────────────
DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# ── Audio ───────────────────────────────────────────────────────────────────
# ponytail: source-only speaker HAL; mic/input/routes later if needed.
PRODUCT_PACKAGES += \
    audio.primary.mt8163 \
    biscuit_audiotrack_test \
    biscuit_audiorecord_test \
    biscuit_mic_test \
    tinymix \
    tinyplay \
    tinycap \
    tinypcminfo

# ── LED ring / buttons ──────────────────────────────────────────────────────
# Source-only Biscuit LED daemon + framework bridge; no stock lights/button blobs.
PRODUCT_PACKAGES += \
    biscuit-ledd \
    biscuit-ledctl \
    biscuit_service \
    BiscuitService

# ── Sensors ─────────────────────────────────────────────────────────────────
PRODUCT_PACKAGES += \
    sensors.mt8163

# ── Platform ────────────────────────────────────────────────────────────────
TARGET_BOARD_PLATFORM  := mt8163
TARGET_BOOTLOADER_BOARD_NAME := biscuit

# ── System properties ───────────────────────────────────────────────────────
PRODUCT_PROPERTY_OVERRIDES += \
    ro.carrier=wifi-only \
    ro.config.low_ram=true \
    debug.hwui.render_dirty_regions=false \
    ro.hardware.gralloc=mt8163.mali

# ── ADB over USB ─────────────────────────────────────────────────────────────
# ponytail: USB debugging enabled by default for bring-up; restrict post-MVP.
ADDITIONAL_DEFAULT_PROPERTIES += \
    ro.adb.secure=0 \
    ro.secure=0 \
    ro.debuggable=1 \
    service.adb.root=1

# ── Ramdisk init ─────────────────────────────────────────────────────────────
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/cacerts.pem:system/etc/security/cacerts.pem \
    $(LOCAL_PATH)/rootdir/fstab.mt8163:root/fstab.mt8163 \
    device/amazon/mt8163-common/rootdir/etc/init.mt8163.rc:root/init.mt8163.rc \
    $(LOCAL_PATH)/rootdir/init.device.rc:root/init.device.rc \
    $(LOCAL_PATH)/rootdir/init.biscuit.usb.rc:root/init.biscuit.usb.rc \
    device/amazon/mt8163-common/rootdir/etc/init.mt8163.usb.rc:root/init.mt8163.usb.rc \
    device/amazon/mt8163-common/rootdir/etc/ueventd.mt8163.rc:root/ueventd.mt8163.rc \
    frameworks/native/data/etc/android.hardware.wifi.xml:system/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:system/etc/permissions/android.hardware.sensor.light.xml \
    $(LOCAL_PATH)/biscuit-service/animations/volume.animation:system/etc/biscuit-ledd/volume.animation \
    $(LOCAL_PATH)/biscuit-service/animations/volume-muted.animation:system/etc/biscuit-ledd/volume-muted.animation \
    $(LOCAL_PATH)/biscuit-service/animations/solid_blue.animation:system/etc/biscuit-ledd/solid_blue.animation \
    $(LOCAL_PATH)/biscuit-service/animations/solid_green.animation:system/etc/biscuit-ledd/solid_green.animation \
    $(LOCAL_PATH)/biscuit-service/animations/solid_cyan.animation:system/etc/biscuit-ledd/solid_cyan.animation \
    $(LOCAL_PATH)/biscuit-service/animations/alexa_thinking.animation:system/etc/biscuit-ledd/alexa_thinking.animation \
    $(LOCAL_PATH)/biscuit-service/animations/boot-complete-green.animation:system/etc/biscuit-ledd/boot-complete-green.animation

# ── AAPT ─────────────────────────────────────────────────────────────────────
PRODUCT_AAPT_CONFIG      := normal mdpi
PRODUCT_AAPT_PREF_CONFIG := mdpi

# ── Languages ────────────────────────────────────────────────────────────────
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)
