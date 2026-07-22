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

# ── Setup wizard ─────────────────────────────────────────────────────────────
# ponytail: no screen/account flow on Echo; keep Provision/ManagedProvisioning for boot state.
PRODUCT_PACKAGES := $(filter-out CyanogenSetupWizard SetupWizard,$(PRODUCT_PACKAGES))

# ── Overlays ────────────────────────────────────────────────────────────────
DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# ── Graphics ────────────────────────────────────────────────────────────────
# ponytail: headless still needs SurfaceFlinger alive; software GLES is enough.
PRODUCT_PACKAGES += \
    libGLES_android

# ── Platform ────────────────────────────────────────────────────────────────
TARGET_BOARD_PLATFORM  := mt8163
TARGET_BOOTLOADER_BOARD_NAME := biscuit

# ── System properties ───────────────────────────────────────────────────────
PRODUCT_PROPERTY_OVERRIDES += \
    ro.carrier=wifi-only \
    ro.config.low_ram=true

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
    device/amazon/mt8163-common/rootdir/etc/init.mt8163.rc:root/init.mt8163.rc \
    $(LOCAL_PATH)/rootdir/init.device.rc:root/init.device.rc \
    device/amazon/mt8163-common/rootdir/etc/init.mt8163.usb.rc:root/init.mt8163.usb.rc \
    device/amazon/mt8163-common/rootdir/etc/ueventd.mt8163.rc:root/ueventd.mt8163.rc

# ── AAPT ─────────────────────────────────────────────────────────────────────
PRODUCT_AAPT_CONFIG      := normal mdpi
PRODUCT_AAPT_PREF_CONFIG := mdpi

# ── Languages ────────────────────────────────────────────────────────────────
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)
