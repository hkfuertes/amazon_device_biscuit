LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_PACKAGE_NAME := BiscuitServiceIntentClient
LOCAL_MODULE_TAGS := optional
LOCAL_PROGUARD_ENABLED := disabled
LOCAL_MANIFEST_FILE := AndroidManifest.xml
LOCAL_SRC_FILES := $(call all-java-files-under, src) $(call all-Iaidl-files-under, src)
include $(BUILD_PACKAGE)
