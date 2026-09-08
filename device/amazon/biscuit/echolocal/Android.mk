LOCAL_PATH := $(call my-dir)

# The source is populated by scripts/prepare-echolocal.sh and scripts/stage-tree.sh.
ifneq ($(wildcard $(LOCAL_PATH)/echod),)
include $(CLEAR_VARS)
LOCAL_MODULE := echod
LOCAL_SRC_FILES := echod
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_PATH := $(TARGET_OUT)/app/echod
# EchoLocal and its host tools retain the stock service path as a compatibility alias.
LOCAL_POST_INSTALL_CMD := $(hide) mkdir -p $(TARGET_OUT_EXECUTABLES) && rm -f $(TARGET_OUT_EXECUTABLES)/ledcontroller && ln -sf /system/app/echod/echod $(TARGET_OUT_EXECUTABLES)/ledcontroller
include $(BUILD_PREBUILT)
endif
