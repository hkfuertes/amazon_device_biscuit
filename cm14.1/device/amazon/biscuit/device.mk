LOCAL_PATH := $(call my-dir)

# Use the CM14.1 MT8163 common tree. Biscuit-specific HALs and apps are deferred.
$(call inherit-product, device/amazon/mt8163-common/mt8163-common.mk)

# FireOS 6 ships this software driver on its headless Biscuit product; build ours from source.
PRODUCT_PACKAGES += \
    audio.primary.mt8163 \
    libGLES_android \
    libtinyalsa \
    libtinyalsa_shim \
    libtinycompress

PRODUCT_COPY_FILES += \
    device/amazon/biscuit/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/wifi/wpa_supplicant_overlay.conf

PRODUCT_CHARACTERISTICS := nosdcard,headless
