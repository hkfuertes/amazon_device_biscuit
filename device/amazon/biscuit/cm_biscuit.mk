# CM14.1 compile baseline for Amazon Biscuit.

$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, vendor/cm/config/common.mk)
$(call inherit-product, device/amazon/biscuit/device.mk)

PRODUCT_NAME := cm_biscuit
PRODUCT_DEVICE := biscuit
PRODUCT_BRAND := Amazon
PRODUCT_MODEL := Echo Dot
PRODUCT_MANUFACTURER := amazon

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.zygote=zygote32
