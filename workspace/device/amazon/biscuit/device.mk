# device.mk — Biscuit-specific packages and properties
# Minimum required to advance to boot-image build.
# Extend in subsequent issues (WiFi, audio, blobs).

LOCAL_PATH := device/amazon/biscuit

# ── Device characteristics ──────────────────────────────────────────────────
# Headless device: no display, no telephony, no sdcard.
PRODUCT_CHARACTERISTICS := nosdcard

# ── Overlays ────────────────────────────────────────────────────────────────
DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# ── Platform ────────────────────────────────────────────────────────────────
TARGET_BOARD_PLATFORM  := mt8163
TARGET_BOOTLOADER_BOARD_NAME := biscuit

# ── System properties ───────────────────────────────────────────────────────
PRODUCT_PROPERTY_OVERRIDES += \
    ro.carrier=wifi-only \
    ro.sf.lcd_density=160 \
    ro.opengles.version=196608

# ── ADB over USB ─────────────────────────────────────────────────────────────
# ponytail: USB debugging enabled by default for bring-up; restrict post-MVP.
ADDITIONAL_DEFAULT_PROPERTIES += \
    ro.adb.secure=0 \
    ro.secure=0 \
    ro.debuggable=1 \
    service.adb.root=1 \
    persist.sys.usb.config=adb

# ── Ramdisk init ─────────────────────────────────────────────────────────────
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/fstab.mt8163:root/fstab.mt8163 \
    $(LOCAL_PATH)/rootdir/init.mt8163.rc:root/init.mt8163.rc \
    $(LOCAL_PATH)/rootdir/init.device.rc:root/init.device.rc \
    $(LOCAL_PATH)/rootdir/init.mt8163.usb.rc:root/init.mt8163.usb.rc

# ── AAPT ─────────────────────────────────────────────────────────────────────
PRODUCT_AAPT_CONFIG      := normal mdpi
PRODUCT_AAPT_PREF_CONFIG := mdpi

# ── Languages ────────────────────────────────────────────────────────────────
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)
