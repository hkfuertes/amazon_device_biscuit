LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_PACKAGE_NAME := BiscuitEmptyLauncher
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := $(call all-java-files-under, src)
LOCAL_SDK_VERSION := current
LOCAL_CERTIFICATE := platform
# ponytail: product make inheritance appends packages late; this is Android's native way
# to keep inherited CM12 apps out while installing our one black HOME.
LOCAL_OVERRIDES_PACKAGES := \
    BasicDreams \
    Browser \
    Calculator \
    Calendar \
    Camera2 \
    CMFileManager \
    CMWallpapers \
    CMUpdater \
    CyanogenSetupWizard \
    DeskClock \
    Development \
    Email \
    Exchange2 \
    Gallery2 \
    Launcher2 \
    Launcher3 \
    LockClock \
    PrintSpooler \
    SetupWizard \
    Terminal \
    ThemeChooser \
    Trebuchet \
    WallpaperCropper
include $(BUILD_PACKAGE)
