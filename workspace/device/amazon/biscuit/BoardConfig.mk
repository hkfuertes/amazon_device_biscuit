# BoardConfig.mk — Amazon Biscuit (Echo Dot 2nd gen)
# SoC: MediaTek MT8163B — quad-core Cortex-A53, ARMv8-A

LOCAL_PATH := device/amazon/biscuit

# ── Architecture ─────────────────────────────────────────────────────────────
TARGET_ARCH          := arm64
TARGET_ARCH_VARIANT  := armv8-a
TARGET_CPU_ABI       := arm64-v8a
TARGET_CPU_ABI2      :=
TARGET_CPU_VARIANT   := cortex-a53

# 32-bit secondary for legacy HALs
TARGET_2ND_ARCH          := arm
TARGET_2ND_ARCH_VARIANT  := armv7-a-neon
TARGET_2ND_CPU_ABI       := armeabi-v7a
TARGET_2ND_CPU_ABI2      := armeabi
TARGET_2ND_CPU_VARIANT   := cortex-a53

# ── Platform ─────────────────────────────────────────────────────────────────
TARGET_BOARD_PLATFORM          := mt8163
TARGET_BOOTLOADER_BOARD_NAME   := biscuit
TARGET_NO_BOOTLOADER           := true
TARGET_NO_RADIOIMAGE            := true

# ── Kernel ───────────────────────────────────────────────────────────────────
# Kernel source is from Amazon Echo Dot 5.5.5.4 release tarball.
# Offsets derived from MT8163 platform convention (amonet boot.hdr is the
# exploit loader, not a stock CM12 boot image — verify offsets on first build).
TARGET_KERNEL_ARCH      := arm64
BOARD_KERNEL_PAGESIZE   := 2048
BOARD_KERNEL_BASE       := 0x40000000
BOARD_KERNEL_OFFSET     := 0x00008000
BOARD_RAMDISK_OFFSET    := 0x04f88000
BOARD_TAGS_OFFSET       := 0x0df88000
# ponytail: cmdline matches Amazon FireOS stock (64N2 = 64-bit normal world).
# androidboot.selinux=permissive for bring-up; remove post-MVP.
BOARD_KERNEL_CMDLINE    := bootopt=64S3,32N2,64N2 androidboot.selinux=permissive

BOARD_MKBOOTIMG_ARGS    := \
    --kernel_offset  $(BOARD_KERNEL_OFFSET)  \
    --ramdisk_offset $(BOARD_RAMDISK_OFFSET) \
    --tags_offset    $(BOARD_TAGS_OFFSET)

# Kernel will be pre-built or built from Amazon source; path TBD in kernel issue.
# TARGET_PREBUILT_KERNEL := $(LOCAL_PATH)/prebuilt/kernel

# ── Partitions ───────────────────────────────────────────────────────────────
# Sizes extracted from gpt-biscuit.bin (amonet v1.1.0, workspace/tools/).
# amonet remaps boot_a/boot_b ↔ boot_a_x/boot_b_x; TWRP/hacked-fastboot handle
# the remap transparently so these values refer to the effective boot slots.
BOARD_BOOTIMAGE_PARTITION_SIZE      := 16777216    # 16 MB  (boot_a / boot_b)
BOARD_RECOVERYIMAGE_PARTITION_SIZE  := 16777216    # 16 MB  (recovery)
BOARD_SYSTEMIMAGE_PARTITION_SIZE    := 805306368   # 768 MB (system_a / system_b)
BOARD_CACHEIMAGE_PARTITION_SIZE     := 822083584   # 784 MB (cache)
# userdata is trimmed ~56 MB by amonet for boot_a_x/boot_b_x carve-out.
BOARD_USERDATAIMAGE_PARTITION_SIZE  := 1258291200  # 1.2 GB (safe, < 1272 MB raw)
BOARD_FLASH_BLOCK_SIZE              := 131072       # 128 KB (eMMC erase block)

# ── Filesystems ──────────────────────────────────────────────────────────────
TARGET_USERIMAGES_USE_EXT4          := true
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE   := ext4

# ── SELinux ──────────────────────────────────────────────────────────────────
# ponytail: permissive for bring-up; policy stubs added here when needed.
BOARD_SEPOLICY_DIRS += $(LOCAL_PATH)/sepolicy

# ── Recovery ─────────────────────────────────────────────────────────────────
# Using TWRP (amonet v1.1.0 twrp.img); stock recovery slot not relied on.
TARGET_RECOVERY_FSTAB := $(LOCAL_PATH)/recovery/root/etc/fstab.mt8163

# ── Misc ─────────────────────────────────────────────────────────────────────
BOARD_HAS_NO_SELECT_BUTTON := true
