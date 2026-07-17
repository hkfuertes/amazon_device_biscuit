# CyanogenMod 12 product definition — Amazon Biscuit (Echo Dot 2nd gen)

$(call inherit-product, device/amazon/biscuit/device.mk)

# Minimal CM12 common: no telephony, no display stack.
# common.mk is the least-opinionated entry point; add common_full_tablet_wifionly.mk
# once the CM12 source tree is present and a richer feature set is desired.
$(call inherit-product-if-exists, vendor/cm/config/common.mk)

PRODUCT_NAME         := cm_biscuit
PRODUCT_DEVICE       := biscuit
PRODUCT_BRAND        := Amazon
PRODUCT_MODEL        := Echo Dot
PRODUCT_MANUFACTURER := amazon
