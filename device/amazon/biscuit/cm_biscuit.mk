# CyanogenMod 12 product definition — Amazon Biscuit (Echo Dot 2nd gen)

# The pinned public prebuilt supplies the main Chromium WebView payload.
PRODUCT_PREBUILT_WEBVIEWCHROMIUM := yes
PRODUCT_PACKAGES += \
    webview

$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, vendor/cm/config/common.mk)
$(call inherit-product, device/amazon/biscuit/device.mk)

PRODUCT_NAME         := cm_biscuit
PRODUCT_DEVICE       := biscuit
PRODUCT_BRAND        := Amazon
PRODUCT_MODEL        := Echo Dot
PRODUCT_MANUFACTURER := amazon

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.zygote=zygote32
