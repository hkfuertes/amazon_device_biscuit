# CM14.1 compile baseline for Amazon Biscuit.
LOCAL_PATH := device/amazon/biscuit

# Legacy recovery OTAs must use amonet v2 TWRP's current-slot aliases.
TARGET_RELEASETOOLS_EXTENSIONS := $(LOCAL_PATH)
# Headless bring-up intentionally permits root, unauthenticated USB ADB.
TARGET_FORCE_INSECURE_ADB := true

include device/amazon/mt8163-common/BoardConfigCommon.mk

TARGET_BOOTLOADER_BOARD_NAME := biscuit
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

# Build the exact FireOS 6.5.7.1 Biscuit kernel source inside CM14.1.
TARGET_KERNEL_SOURCE := kernel/amazon/biscuit
TARGET_KERNEL_CONFIG := biscuit_defconfig
TARGET_KERNEL_ARCH := arm
TARGET_KERNEL_HEADER_ARCH := arm
TARGET_KERNEL_CROSS_COMPILE_PREFIX := arm-eabi-
KERNEL_TOOLCHAIN := $(ANDROID_BUILD_TOP)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin
TARGET_LINUX_KERNEL_VERSION := 3.18
# ponytail: compile .ko files but skip unavailable FireOS module installation.
TARGET_KERNEL_MODULES := biscuit-kernel-modules-built
BOARD_KERNEL_IMAGE_NAME := zImage-dtb
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_PAGESIZE := 2048
# Fire OS 6 stock boot.img loads the ARM zImage-dtb at 0x40008000.
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x04000000
BOARD_SECOND_OFFSET := 0x00f00000
BOARD_TAGS_OFFSET := 0x08000000
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,32N2 androidboot.selinux=permissive
BOARD_MKBOOTIMG_ARGS := \
    --base $(BOARD_KERNEL_BASE) \
    --kernel_offset $(BOARD_KERNEL_OFFSET) \
    --ramdisk_offset $(BOARD_RAMDISK_OFFSET) \
    --second_offset $(BOARD_SECOND_OFFSET) \
    --tags_offset $(BOARD_TAGS_OFFSET)

BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 16777216
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 805306368
BOARD_CACHEIMAGE_PARTITION_SIZE := 822083584
BOARD_USERDATAIMAGE_PARTITION_SIZE := 1325383168
BOARD_FLASH_BLOCK_SIZE := 131072

BOARD_HAS_NO_SELECT_BUTTON := true
