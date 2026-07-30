# CM12 for Amazon Biscuit (Echo Dot 2nd gen)

CyanogenMod 12 port for Amazon Biscuit with reproducible inputs and a disposable `workspace/`.

> Nothing here flashes the device. Scripts only produce build artifacts. Flashing notes live in `docs/amonet-biscuit-unlock.md`.

## Layout

```txt
manifest/   # pinned CM12/AOSP repo manifest
sources/    # tracked device/hardware work
patches/    # reproducible CM12/kernel patches
docker/     # build images
scripts/    # bootstrap, preflight, build, extract helpers
docs/       # notes, source list, useful logs
workspace/  # ignored: downloads, cm12 checkout, kernel, blobs, outputs
```

## Reproducible inputs

```txt
workspace/cm12
  <- scripts/sync-cm12.sh
  <- manifest/cm12.lock.xml

workspace/kernel/amazon/biscuit
  <- scripts/prepare-kernel-source.sh
  <- Amazon Echo Dot 5.5.5.4 source tarball
  <- sha256 dd92a7ddd7c0fb9b61455542b84132ad00a445c38ef4f910b1272ac04f6f83dd

workspace/vendor/amazon/biscuit
  <- scripts/extract-biscuit-stock-blobs.sh <system.img>
  <- stock Biscuit OTA `system.new.dat` + `system.transfer.list` converted to `system.img`
```

See `docs/sources.md` for URLs and exact source policy.

## Minimal flow

```sh
scripts/bootstrap-workspace.sh
scripts/preflight.sh
scripts/build-kernel.sh
scripts/build.sh
```

`build.sh` keeps `workspace/cm12/out-docker/` by default for incremental builds. Partial cleanups are opt-in:

```sh
CLEAN_BISCUIT_OUT=1 scripts/build.sh
CLEAN_KERNEL_OUT=1 scripts/build-kernel.sh
```

## Proprietary blobs

Blobs are not committed. Extract them from the stock OTA into `workspace/vendor/amazon/biscuit/`; `scripts/stage-tree.sh` copies them into the CM12 checkout.

## Credits and upstreams

This project stands on:

- CyanogenMod/LineageOS CM12.1 and AOSP trees, synced through `manifest/cm12.lock.xml`.
- Amazon OSS `android_device_amazon_mt8163-common`: base MT8163 device-common tree.
- Amazon OSS `android_hardware_amazon`: Amazon hardware helpers.
- Amazon Echo Dot 5.5.5.4 kernel source tarball from Amazon's Fire OS source release.
- Amazon Biscuit stock OTA `272.6.4.1` for proprietary blobs.
- MTK helper references from `lbule/android_hardware_mediatek`, used only for comparison of driver-command behavior.
- The amonet Biscuit unlock/recovery work documented in `docs/amonet-biscuit-unlock.md`.

Tracked changes in this repo are the Biscuit-specific glue, patches, scripts, and documentation needed to rebuild the workspace.

## Safety

- Never run `adb shell dd of=/dev/block/...`.
- Do not use stock fastboot for ROM images.
- Do not touch GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc unless explicitly requested.
