LOCAL_PATH := $(call my-dir)

# The source is populated by scripts/prepare-echolocal.sh and scripts/stage-tree.sh.
ifneq ($(wildcard $(LOCAL_PATH)/echod),)
include $(CLEAR_VARS)
LOCAL_MODULE := echod
LOCAL_SRC_FILES := echod
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_PATH := $(TARGET_OUT_EXECUTABLES)
# Keep EchoLocal's expected app path and stock service path as compatibility aliases.
# /system/bin receives CM12's executable mode in target-files; /system/app does not.
LOCAL_POST_INSTALL_CMD := $(hide) mkdir -p $(TARGET_OUT)/app/echod && rm -f $(TARGET_OUT)/app/echod/echod && ln -sf /system/bin/echod $(TARGET_OUT)/app/echod/echod && rm -f $(TARGET_OUT_EXECUTABLES)/ledcontroller && ln -sf /system/app/echod/echod $(TARGET_OUT_EXECUTABLES)/ledcontroller
include $(BUILD_PREBUILT)
endif
