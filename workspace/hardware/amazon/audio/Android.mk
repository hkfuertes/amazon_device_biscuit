LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := audio.primary.mt8163
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_SRC_FILES := audio_wrapper.c
LOCAL_SHARED_LIBRARIES := liblog libcutils libhardware
LOCAL_MODULE_TAGS := optional
LOCAL_CFLAGS := -Wno-unused-parameter

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := biscuit_audiotrack_test
LOCAL_SRC_FILES := biscuit_audiotrack_test.cpp
LOCAL_SHARED_LIBRARIES := libmedia libutils liblog
LOCAL_MODULE_TAGS := optional
LOCAL_CFLAGS := -Wno-unused-parameter

include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)

LOCAL_MODULE := biscuit_audio_echo_test
LOCAL_SRC_FILES := biscuit_audio_echo_test.cpp
LOCAL_SHARED_LIBRARIES := libmedia libutils liblog
LOCAL_MODULE_TAGS := optional
LOCAL_CFLAGS := -Wno-unused-parameter

include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)

LOCAL_MODULE := biscuit_audiorecord_test
LOCAL_SRC_FILES := biscuit_audiorecord_test.cpp
LOCAL_SHARED_LIBRARIES := libmedia libutils liblog
LOCAL_MODULE_TAGS := optional
LOCAL_CFLAGS := -Wno-unused-parameter

include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)

LOCAL_MODULE := biscuit_mic_test
LOCAL_SRC_FILES := biscuit_mic_test.c
LOCAL_C_INCLUDES := external/tinyalsa/include
LOCAL_SHARED_LIBRARIES := liblog libcutils libtinyalsa
LOCAL_MODULE_TAGS := optional
LOCAL_CFLAGS := -Wno-unused-parameter -std=gnu99

include $(BUILD_EXECUTABLE)
