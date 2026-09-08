# Frameworkless Biscuit bootstrap product.
# It intentionally does not inherit full_base, core_minimal, core_tiny, or CM common.

$(call inherit-product, device/amazon/biscuit/biscuit_bootstrap_device.mk)

PRODUCT_NAME         := biscuit_bootstrap
PRODUCT_DEVICE       := biscuit
PRODUCT_BRAND        := Amazon
PRODUCT_MODEL        := Echo Dot Bootstrap
PRODUCT_MANUFACTURER := amazon

PRODUCT_CHARACTERISTICS := nosdcard

# The future installer uses this to select its standalone service path.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.echolocal.install_mode=standalone \
    ro.echolocal.service=echod
