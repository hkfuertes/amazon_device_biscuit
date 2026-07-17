# Boot image status

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

## Blocker for full `boot.img`

A boot image also needs a ramdisk (`ramdisk.img`). Amazon source provides kernel source, not a CM12 ramdisk. No old repo/tree was used.

Next clean step: sync/build CM12 in `workspace/cm12`, generate `ramdisk.img`, then run:

```sh
workspace/scripts/build-boot-img.sh
```

No flashing was done.
