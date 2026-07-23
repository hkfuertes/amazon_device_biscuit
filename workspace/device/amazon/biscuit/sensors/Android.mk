LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_SHARED_LIBRARIES := liblog libcutils
LOCAL_SRC_FILES := sensors_biscuit.c
LOCAL_MODULE := sensors.mt8163
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)
