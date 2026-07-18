# CyanogenMod 12 product definition — Amazon Biscuit (Echo Dot 2nd gen)

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/embedded.mk)
$(call inherit-product, device/amazon/biscuit/device.mk)

PRODUCT_RUNTIMES := runtime_libart_default
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.zygote=zygote64_32

PRODUCT_NAME         := cm_biscuit
PRODUCT_DEVICE       := biscuit
PRODUCT_BRAND        := Amazon
PRODUCT_MODEL        := Echo Dot
PRODUCT_MANUFACTURER := amazon
