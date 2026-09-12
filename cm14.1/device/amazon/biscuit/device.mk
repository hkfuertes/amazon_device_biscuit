LOCAL_PATH := $(call my-dir)

# Use the CM14.1 MT8163 common tree; keep Biscuit additions native/minimal.
$(call inherit-product, device/amazon/mt8163-common/mt8163-common.mk)

# FireOS 6 ships this software driver on its headless Biscuit product; build ours from source.
PRODUCT_PACKAGES += \
    audio.primary.mt8163 \
    libGLES_android \
    libtinyalsa \
    libtinyalsa_shim \
    libtinycompress

# Native LED ring controller; Java bridge stays out until a real UI/API needs it.
PRODUCT_PACKAGES += \
    biscuit-ledd \
    biscuit-ledctl

PRODUCT_COPY_FILES += \
    device/amazon/biscuit/rootdir/init.device.rc:root/init.device.rc \
    device/amazon/biscuit/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/wifi/wpa_supplicant_overlay.conf \
    device/amazon/biscuit/biscuit-service/animations/volume.animation:$(TARGET_COPY_OUT_SYSTEM)/etc/biscuit-ledd/volume.animation \
    device/amazon/biscuit/biscuit-service/animations/volume-muted.animation:$(TARGET_COPY_OUT_SYSTEM)/etc/biscuit-ledd/volume-muted.animation \
    device/amazon/biscuit/biscuit-service/animations/solid_blue.animation:$(TARGET_COPY_OUT_SYSTEM)/etc/biscuit-ledd/solid_blue.animation \
    device/amazon/biscuit/biscuit-service/animations/solid_green.animation:$(TARGET_COPY_OUT_SYSTEM)/etc/biscuit-ledd/solid_green.animation \
    device/amazon/biscuit/biscuit-service/animations/solid_cyan.animation:$(TARGET_COPY_OUT_SYSTEM)/etc/biscuit-ledd/solid_cyan.animation \
    device/amazon/biscuit/biscuit-service/animations/alexa_thinking.animation:$(TARGET_COPY_OUT_SYSTEM)/etc/biscuit-ledd/alexa_thinking.animation \
    device/amazon/biscuit/biscuit-service/animations/boot-complete-green.animation:$(TARGET_COPY_OUT_SYSTEM)/etc/biscuit-ledd/boot-complete-green.animation

PRODUCT_CHARACTERISTICS := nosdcard,headless
