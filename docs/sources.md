# Reproducible sources

## Android tree

- Manifest overlay: `manifest/local.xml`
- Resolved lock manifest: `manifest/lock.xml`
- Sync: `scripts/sync.sh`
- Ignored destination: `workspace/cm14.1/`
- Upstream branch: LineageOS `cm-14.1`

## Fire OS 6 kernel source

- Source: Amazon Echo Dot 6.5.7.1
- URL: `https://fireos-audio-src.s3.amazonaws.com/dMUQiRDxI3hFuRDaF0WTumrp71/Echo_Dot_src-6.5.7.1-20251024.tar.bz2`
- SHA256: `2f6b7eed8c09cecf7633f01909c6a4085bef691c29ed0d106c75e7b48c7b4721`
- Staging: `scripts/stage-tree.sh`
- Ignored staged kernel: `workspace/cm14.1/kernel/amazon/biscuit/`
- Patches: `patches/kernel/`, strict `-p4 --fuzz=0`, filename order
- As-is comparison build: `scripts/build-kernel-as-is.sh`

Policy: keep `CONFIG_CMDLINE_FORCE=y` with `root=/dev/ram rdinit=/init`; import only reviewed safe boot arguments through patches.

## Fire OS 6.5.7.4 Biscuit/Puffin blobs

- Source OTA: `https://d1s31zyz7dcc2d.cloudfront.net/2026/8/3/f49aaff7-dd63-4d9c-9e9a-c17498267de5/update-kindle-biscuit_puffin-NS6574_user_7623_0013121734532.bin`
- OTA SHA256: `64ab6d2dd85f8093abdd62c275d229c7e9fdd68e4d46892b48bdbd1d100d46d8`
- Reconstructor: `scripts/extract-fireos6-payload.py`
- Verified system image: `workspace/extracted/biscuit-fireos-6.5.7.4/system.img`
- System image SHA256: `eccfa850c3009d5454f69a411c0b757be642059b3224cae8fc941fa0dd22c570`
- Extractor: `scripts/extract-fireos6-blobs.sh`
- Tracked manifests:
  - `vendor/amazon/mt8163-common/fireos6-audio-files.txt`
  - `vendor/amazon/mt8163-common/biscuit-radio-files.txt`
  - `vendor/amazon/mt8163-common/biscuit-bluetooth-files.txt`

The extractor verifies every blob by size and SHA-256, stages untracked files under `workspace/cm14.1/vendor/amazon/mt8163-common/proprietary/`, and writes the generated vendor makefile only when content changed.

## Stock Biscuit graphics blob

- Source OTA: `https://d1s31zyz7dcc2d.cloudfront.net/8811a0fc982bf3331dc54f5aec45d936/update-kindle-full_biscuit-272.6.4.1_user_641575220.bin`
- OTA SHA256: `28bc050e4a2af79c9ca66e251de7bf04c42ce8d7934dd97673d3d04f5fa0917b`
- Verified system image: `workspace/extracted/biscuit-stock-272.6.4.1/system.img`
- System image SHA256: `bd928aa5087b8d8c40095c784dfc159cc2555ed4130d617b258bfd0a06659f7c`
- Tracked manifest: `vendor/amazon/mt8163-common/biscuit-headless-hwc-files.txt`

Policy: use only the verified headless HWC blob required by SurfaceFlinger; do not import a wider graphics stack without a separate validated need.

## Patch policy

```txt
patches/full/    Android tree patches for the full `cm_biscuit-userdebug` product
patches/kernel/  Fire OS 6 kernel patches
```

Both folders are applied by `scripts/apply-patches.sh` in lexicographic filename order. Number filenames when order matters. If a patch is optional or product-specific future work, keep it out of the always-applied folder.

## Media and build-variant policy

- MTK OMX runtime integration is not imported unless a clearly licensed, verified, and tested source appears.
- Google/FFmpeg/FLAC software codecs are source-built.
- Amazon HAL, audio tuning, radio, Bluetooth, and verified headless graphics blobs are permitted binary dependencies until validated source replacements exist.
- Supported build variant is `userdebug`: root ADB and permissive SELinux are development choices, not production hardening.

## External references used

- Amazon OSS MT8163 common: `https://github.com/amazon-oss/android_device_amazon_mt8163-common`
- MT8163-dev common reference: `https://github.com/mt8163-dev/android_device_amazon_mt8163-common/tree/cm-14.1`
- MT8163-dev vendor reference: `https://github.com/mt8163-dev/android_vendor_amazon_mt8163-common/tree/cm-14.1`
- MTK helper comparison reference: `https://github.com/lbule/android_hardware_mediatek`
