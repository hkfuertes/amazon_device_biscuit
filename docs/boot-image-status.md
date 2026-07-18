# Boot/OTA image status

## Done

Amazon Echo Dot 5.5.5.4 source was downloaded and verified:

- tarball: `workspace/downloads/Echo_Dot_src-5.5.5.4-20220824.tar.bz2`
- sha256: `dd92a7ddd7c0fb9b61455542b84132ad00a445c38ef4f910b1272ac04f6f83dd`

Kernel built in Docker container `biscuit-kernel-build` from Amazon source only:

- artifact: `workspace/kernel-out/arch/arm64/boot/Image.gz-dtb`
- sha256: `450732dc04f541cf57fe5515afe040d61150462d0090f50d02f8dc2d8a29adb1`
- logs: `docker logs biscuit-kernel-build`

The same kernel was copied to ignored CM12 prebuilt location:

- `workspace/device/amazon/biscuit/prebuilt/kernel`

CM12 boot image now builds in Docker:

- command: `BUILD_TARGET=bootimage workspace/scripts/build.sh`
- artifact: `workspace/cm12/out-docker/target/product/biscuit/boot.img`
- sha256: `ac6031d733a0e18f609f830142588a60ce86acbe23105bdab6566d78d91a0b8c`

A minimal flashable CM12 OTA now builds in Docker:

- command: `BUILD_TARGET=otapackage workspace/scripts/build.sh`
- artifact: `workspace/cm12/out-docker/target/product/biscuit/cm_biscuit-ota-c80694a829.zip`
- sha256: `cd67f52a32133c7dfcc50fcc8ebc3d810a34f4c1f9f7dbc53275e310aeca295e`
- system.img sha256: `c893da1750871947e805402171a7e7cc044df6e39c739ffdc95fcd8791d95b66`

The OTA updater script writes:

- system: `/dev/block/platform/mtk-msdc.0/by-name/system_a`
- boot: `/dev/block/platform/mtk-msdc.0/by-name/boot_a_x`

No flashing was done.

## Caveats

- This is a bring-up/minimal image, not a complete usable ROM.
- Device blobs/HALs are still missing.
- Flash only from TWRP/amonet flow after explicit confirmation; never with `adb dd`.
