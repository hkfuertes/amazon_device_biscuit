# Device Tree Decisions — Amazon Biscuit (Echo Dot 2nd gen)

## Location

`device/amazon/biscuit/` — tracked in this repo.
Copied to `workspace/cm12/device/amazon/biscuit` by `stage-tree.sh` when CM12 source is present.

## What is (and isn't) here

This is the **minimum** tree to satisfy `lunch cm_biscuit-userdebug` and to carry
enough board facts for a first boot image attempt.  It deliberately omits:

- WiFi firmware and HAL (separate issue)
- Audio HAL, mixer_paths.xml, audio_policy.conf (separate issue)
- init.rc / ueventd.rc / init.mt8163.rc (separate issue — init bring-up)
- Kernel source or prebuilt (separate issue — kernel integration)
- Proprietary blobs (separate issue)
- SELinux policy rules (placeholder dir only; full policy in a later issue)

## File-by-file decisions

### `AndroidProducts.mk`
Standard CM12 pattern: lists `cm_biscuit.mk` via `$(LOCAL_DIR)`.  
**Generated from scratch** — not in Amazon source (Amazon uses their own product
names, not `cm_*`).

### `cm_biscuit.mk`
**Generated from scratch.**  Amazon source has no CM12 product file.  
Inherits `vendor/cm/config/common.mk` with `inherit-product-if-exists` so the
tree can live outside a full CM12 checkout for static validation.  
`common.mk` chosen over `common_full_tablet_wifionly.mk` to avoid pulling in
display/telephony stacks that Biscuit doesn't have.

### `device.mk`
**Generated from scratch.**  Amazon's device.mk targets FireOS (custom Kindle
stack, not CM12-compatible).  Importing it wholesale would drag in FireOS
services and proprietary package lists that would break the build.  
Current content: bare-minimum properties for bring-up (ADB default-on,
permissive SELinux, wifi-only carrier flag).

### `BoardConfig.mk`
**Generated from scratch.**  Amazon's BoardConfig.mk references internal
MediaTek BSP paths not available in the public release tarball.

**Partition sizes** — extracted directly from  
`workspace/tools/amonet-biscuit-v1.1.0/amonet/bin/gpt-biscuit.bin` (real
on-device GPT):

| Partition  | Raw size  | `BOARD_*IMAGE_PARTITION_SIZE` |
|------------|-----------|-------------------------------|
| boot_a/b   | 16 MB     | 16 777 216                    |
| recovery   | 16 MB     | 16 777 216                    |
| system_a/b | 768 MB    | 805 306 368                   |
| cache      | 784 MB    | 822 083 584                   |
| userdata   | ~1272 MB  | 1 258 291 200 (1.2 GB, safe)  |

userdata is declared at 1.2 GB (< 1272 MB raw) because amonet carves ~56 MB
from the end for `boot_a_x`/`boot_b_x` slots.

**Kernel offsets** — the `boot.hdr` inside amonet v1.1.0 is the exploit loader
(page_size=64, non-standard) and is **not** a stock Android boot image.
Offsets are set to the MT8163 platform convention used by TWRP and known MT8163
CM12 ports; must be verified against the first CM12 kernel build.

### `sepolicy/`
Empty placeholder dir.  `BOARD_SEPOLICY_DIRS` is set now so future policy
files can be added without touching BoardConfig.

### `recovery/root/etc/fstab.mt8163`
Hand-crafted from GPT data.  Block device paths follow the MTK `by-name`
symlink convention (`/dev/block/platform/mtk-msdc.0/by-name/…`).  
Actual eMMC controller path needs to be confirmed on-device (check
`/sys/block/mmcblk0/device/../subsystem -> ...` or TWRP dmesg).

## Amazon source relationship

| This file          | Amazon upstream equivalent           | Relationship        |
|--------------------|--------------------------------------|---------------------|
| `AndroidProducts.mk` | `device/amazon/biscuit/AndroidProducts.mk` | Hand-written (different product names) |
| `cm_biscuit.mk`    | n/a                                  | Hand-written        |
| `device.mk`        | `device/amazon/biscuit/device.mk`    | Written from scratch; Amazon version references FireOS-only paths |
| `BoardConfig.mk`   | `device/amazon/biscuit/BoardConfig.mk` | Written from scratch; partition sizes from real GPT binary |
| `fstab.mt8163`     | `device/amazon/biscuit/fstab.mt8163` | Hand-crafted from GPT; paths TBC on device |
