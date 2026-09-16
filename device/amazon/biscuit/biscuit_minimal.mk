# Framework-free Biscuit base product.
# It intentionally does not inherit full_base or CM common.

$(call inherit-product, device/amazon/biscuit/biscuit_minimal_device.mk)

PRODUCT_NAME := biscuit_minimal
PRODUCT_DEVICE := biscuit
PRODUCT_BRAND := Amazon
PRODUCT_MODEL := Echo Dot Minimal Base
PRODUCT_MANUFACTURER := amazon

PRODUCT_CHARACTERISTICS := nosdcard,headless

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.zygote=zygote32
