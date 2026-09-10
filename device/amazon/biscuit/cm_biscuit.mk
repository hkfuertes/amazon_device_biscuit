# CyanogenMod 12 product definition — Amazon Biscuit (Echo Dot 2nd gen)

# Set BISCUIT_PREBUILT_WEBVIEW=no to compile the Chromium WebView sources.
BISCUIT_PREBUILT_WEBVIEW ?= yes
ifeq ($(BISCUIT_PREBUILT_WEBVIEW),yes)
PRODUCT_PREBUILT_WEBVIEWCHROMIUM := yes
else ifeq ($(BISCUIT_PREBUILT_WEBVIEW),no)
PRODUCT_PREBUILT_WEBVIEWCHROMIUM := no
else
$(error BISCUIT_PREBUILT_WEBVIEW must be yes or no)
endif
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
