LOCAL_PATH := $(call my-dir)

# Use the CM14.1 MT8163 common tree. Biscuit-specific HALs and apps are deferred.
$(call inherit-product, device/amazon/mt8163-common/mt8163-common.mk)

PRODUCT_CHARACTERISTICS := nosdcard
