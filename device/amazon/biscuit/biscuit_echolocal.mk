# Frameworkless EchoLocal product for Biscuit.
# Keep the generic bootstrap product intact and select only this product's init wrapper.
BISCUIT_BOOTSTRAP_INIT_RC := device/amazon/biscuit/rootdir/init.biscuit.echolocal.rc

$(call inherit-product, device/amazon/biscuit/biscuit_bootstrap_device.mk)

LOCAL_PATH := device/amazon/biscuit

PRODUCT_NAME         := biscuit_echolocal
PRODUCT_DEVICE       := biscuit
PRODUCT_BRAND        := Amazon
PRODUCT_MODEL        := Echo Dot
PRODUCT_MANUFACTURER := amazon
PRODUCT_CHARACTERISTICS := nosdcard

# scripts/prepare-echolocal.sh stages this verified release artifact before lunch.
PRODUCT_PACKAGES += echod

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/echolocal-bootstrap.sh:system/bin/echolocal-bootstrap.sh \
    $(LOCAL_PATH)/rootdir/start_animation.sh:system/bin/start_animation.sh \
    $(LOCAL_PATH)/rootdir/stop_animation.sh:system/bin/stop_animation.sh \
    $(LOCAL_PATH)/echolocal/models/okay_nabu.json:system/etc/echolocal/models/okay_nabu.json \
    $(LOCAL_PATH)/echolocal/models/okay_nabu.tflite:system/etc/echolocal/models/okay_nabu.tflite \
    $(LOCAL_PATH)/echolocal/models/hey_jarvis.json:system/etc/echolocal/models/hey_jarvis.json \
    $(LOCAL_PATH)/echolocal/models/hey_jarvis.tflite:system/etc/echolocal/models/hey_jarvis.tflite \
    $(LOCAL_PATH)/echolocal/models/hey_mycroft.json:system/etc/echolocal/models/hey_mycroft.json \
    $(LOCAL_PATH)/echolocal/models/hey_mycroft.tflite:system/etc/echolocal/models/hey_mycroft.tflite
