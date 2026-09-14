LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := biscuit_audiotrack_test
LOCAL_SRC_FILES := biscuit_audiotrack_test.cpp
LOCAL_SHARED_LIBRARIES := libmedia libutils liblog libm
LOCAL_MODULE_TAGS := optional
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := biscuit_audiorecord_test
LOCAL_SRC_FILES := biscuit_audiorecord_test.cpp
LOCAL_SHARED_LIBRARIES := libmedia libutils liblog libm
LOCAL_MODULE_TAGS := optional
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := biscuit_asp_beam_probe
LOCAL_SRC_FILES := biscuit_asp_beam_probe.cpp
LOCAL_SHARED_LIBRARIES := libbinder libmedia libutils liblog
LOCAL_MODULE_TAGS := optional
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := biscuit_mic_test
LOCAL_SRC_FILES := biscuit_mic_test.c
LOCAL_C_INCLUDES := external/tinyalsa/include
LOCAL_SHARED_LIBRARIES := libtinyalsa liblog libm
LOCAL_MODULE_TAGS := optional
include $(BUILD_EXECUTABLE)
