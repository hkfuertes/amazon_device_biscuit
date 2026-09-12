LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := biscuit-ledd
LOCAL_SRC_FILES := biscuit-ledd.cpp
LOCAL_CPPFLAGS := -std=gnu++11 -Wall -Werror
LOCAL_MODULE_TAGS := optional
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := biscuit-ledctl
LOCAL_SRC_FILES := biscuit-ledctl.cpp
LOCAL_CPPFLAGS := -std=gnu++11 -Wall -Werror
LOCAL_MODULE_TAGS := optional
include $(BUILD_EXECUTABLE)
