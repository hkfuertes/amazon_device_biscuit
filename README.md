# CM14.1 for Amazon Biscuit (Echo Dot 2nd gen)

LineageOS/CM14.1 port for Amazon Biscuit with reproducible inputs and a disposable `workspace/`.

Current goal: a safe, rebuildable full CM14.1 image that boots on amonet v2, keeps root ADB for development, and supports Biscuit Wi-Fi, Bluetooth A2DP sink, LED/buttons, microphone capture/mute, and framework audio playback.

> Nothing here flashes the device. Build scripts only produce artifacts. Flashing notes live in `docs/amonet-biscuit-unlock.md`.

## Layout

```txt
manifest/   # pinned CM14.1 repo manifests
patches/    # ordered full-product and kernel patch series
device/     # tracked Biscuit device overlay
vendor/     # tracked proprietary-blob manifests and generated makefile template
docker/     # build images
scripts/    # sync, stage, build, extraction, and diagnostics
docs/       # notes, source list, and validation guides
workspace/  # ignored: downloads, CM14.1 checkout, extracted blobs, outputs, ccache
```

The active source layout is flat. `workspace/cm14.1` remains only the external LineageOS checkout.

## Reproducible inputs

```txt
workspace/cm14.1
  <- scripts/sync.sh
  <- manifest/local.xml or manifest/lock.xml

workspace/upstream/amazon-echo-dot-6.5.7.1
  <- scripts/stage-tree.sh
  <- verified Fire OS 6.5.7.1 Echo Dot source archive

workspace/extracted/biscuit-fireos-6.5.7.4/system.img
  <- scripts/extract-fireos6-payload.py
  <- verified Fire OS 6.5.7.4 Biscuit/Puffin OTA

workspace/extracted/biscuit-stock-272.6.4.1/system.img
  <- scripts/prepare-biscuit-stock-system-image.sh
  <- verified stock Biscuit OTA used for the headless HWC blob
```

See `docs/sources.md` for URLs, hashes, and policy.

## Build

One-time Docker images, if missing:

```sh
docker image inspect cm14.1-ubuntu20:latest >/dev/null 2>&1 || \
  docker build -t cm14.1-ubuntu20:latest -f docker/cm14.1-ubuntu20.Dockerfile docker/

docker image inspect biscuit-kernel-builder:latest >/dev/null 2>&1 || \
  docker build -t biscuit-kernel-builder:latest -f docker/biscuit-kernel-builder.Dockerfile docker/
```

Sync and build:

```sh
scripts/sync.sh
make full
docker logs -f cm14.1-biscuit-build
```

`make full` is a thin alias for `scripts/build.sh`. It stages the flat overlay, applies every patch in `patches/full/`, extracts verified Fire OS blobs, stages the Fire OS 6 kernel, applies every patch in `patches/kernel/`, and launches a detached `cm14.1-biscuit-build` container.

The OTA is written under:

```txt
workspace/cm14.1/out-docker/target/product/biscuit/
```

## Patch layout

```txt
patches/full/    # full cm_biscuit-userdebug Android tree patches, applied in filename order
patches/kernel/  # Fire OS 6 Biscuit kernel patches, applied in filename order
```

Patch filenames are numbered because order matters. If a patch is not always part of the full product, do not keep it in `patches/full/`.

## Useful checks

```sh
bash tests/test-apply-patches.sh
bash tests/test-compatibility.sh
bash tests/test-kernel-root-cmdline.sh
bash tests/test-amonet2-bcb-slotselect.sh
python3 tests/test-ota-slot-paths.py
bash tests/test-led-countdown.sh
git diff --check
```

## Runtime helpers

Current builds include `/system/bin/biscuit_service`:

```sh
adb shell biscuit_service wifi on
adb shell biscuit_service wifi connect '<ssid>' '<psk>'
adb shell biscuit_service wifi off
adb shell biscuit_service volume up
adb shell biscuit_service volume down
adb shell biscuit_service volume set '<0..max>'
adb shell biscuit_service mute on|off|toggle
adb shell biscuit_service mic mute|unmute|toggle
adb shell biscuit_service countdown set '<remaining-ms>' '<total-ms>'
adb shell biscuit_service countdown clear
adb shell biscuit_service bt pair
adb shell biscuit_service bt off
```

Do not print Wi-Fi PSKs in logs or summaries.

## Safety

- Never run `adb shell dd of=/dev/block/...` or `adb exec-in dd of=/dev/block/...`.
- Use confirmed amonet v2 TWRP sideload for ROM updates.
- Do not use stock fastboot for ROM images.
- Do not touch GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc unless explicitly requested.
- Inspect every generated updater before flashing; valid custom OTAs write only `/dev/block/current-system` and `/dev/block/current-boot`.
