# CM12 for Amazon Biscuit (Echo Dot 2nd gen)

CyanogenMod 12 port for Amazon Biscuit with reproducible inputs and a disposable `workspace/`.

Goal: a safe, rebuildable CM12 image for Biscuit that boots with ADB, WiFi, speaker playback, and microphone capture. Polish comes later.

> Nothing here flashes the device. Scripts only produce build artifacts. Flashing notes live in `docs/amonet-biscuit-unlock.md`.

## Layout

```txt
manifest/   # pinned CM12/AOSP repo manifest
device/     # tracked Biscuit device trees
hardware/   # tracked Amazon/MediaTek helpers
patches/    # target-scoped CM12/kernel/vendor patch series
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
  <- verified, unmodified Amazon Echo Dot 5.5.5.4 source
  <- sha256 dd92a7ddd7c0fb9b61455542b84132ad00a445c38ef4f910b1272ac04f6f83dd

workspace/kernel/build/biscuit
  <- scripts/stage-kernel-for-build.sh
  <- disposable patched build stage

workspace/vendor/amazon/biscuit
  <- scripts/extract-biscuit-stock-blobs.sh <system.img>
  <- stock Biscuit OTA `system.new.dat` + `system.transfer.list` converted to `system.img`
```

See `docs/sources.md` for URLs plus source, media, and build-variant policy.

## Build

The build deliberately has two Docker stages: a reproducibly generated kernel,
then the CM12 OTA that consumes that generated kernel as a prebuilt. The
Amazon kernel source and every output remain ignored under `workspace/`; only
the recipe and patch series are tracked.

One-time CM12 Docker image, if missing:

```sh
docker image inspect cm12-ubuntu14:latest >/dev/null 2>&1 || \
  docker build -t cm12-ubuntu14:latest -f docker/cm12-ubuntu14.Dockerfile docker/
```

### Clean build from an empty `workspace/`

```sh
# Optional destructive clean: removes only ignored downloads, sources, blobs, and outputs.
rm -rf workspace

# Materialize all reproducible external inputs.
scripts/bootstrap-workspace.sh

# Build the patched kernel in its dedicated Docker image.
scripts/build-kernel.sh

# Read-only gate: verify inputs, pins, blobs, generated kernel, and host tools.
scripts/preflight.sh

# Stage tracked trees and launch the detached CM12 userdebug OTA build.
scripts/build.sh
docker logs -f cm12-biscuit-build
```

The commands have distinct responsibilities:

| Command | What it does |
| --- | --- |
| `scripts/bootstrap-workspace.sh` | Syncs the pinned CM12 manifest, verifies/extracts the unmodified Amazon kernel base, materializes the pinned CA bundle, prepares the stock system image, extracts and vendor-patches blobs, then stages tracked trees and CM12 patches. |
| `scripts/build-kernel.sh` | Copies the verified kernel base to a disposable stage, applies `patches/kernel/`, builds `Image.gz-dtb` with the dedicated toolchain container, and places the generated prebuilt under ignored `workspace/`. It creates `biscuit-kernel-builder:latest` if needed. |
| `scripts/preflight.sh` | Performs no download, sync, build, or flash. It fails with a specific missing-input command if the workspace is incomplete. Run it explicitly before every OTA build. |
| `scripts/build.sh` | Re-stages tracked `device/` and `hardware/` trees, vendor inputs, CA files, and `patches/cm12/`; then starts `make otapackage` in detached `cm12-biscuit-build`. It does **not** run `preflight.sh` itself. |

The OTA is written under:

```txt
workspace/cm12/out-docker/target/product/biscuit/
```

### Incremental builds

For ordinary CM12/device changes with an existing valid kernel:

```sh
scripts/preflight.sh
scripts/build.sh
docker logs -f cm12-biscuit-build
```

If the Amazon kernel source recipe or `patches/kernel/` changed, rebuild the
kernel first. Clean outputs only when a clean rebuild is intended:

```sh
CLEAN_KERNEL_OUT=1 scripts/build-kernel.sh
scripts/preflight.sh
CLEAN_BISCUIT_OUT=1 scripts/build.sh
docker logs -f cm12-biscuit-build
```

`BUILD_KERNEL=1 scripts/build.sh` is a convenience form that runs the separate
kernel builder before launching CM12; it does not make the kernel part of the
CM12 Make dependency graph. Prefer the explicit sequence above when monitoring
or diagnosing the two builds separately.

## Biscuit intents

Current builds expose these system intents for APKs and shell helpers.

### Button broadcasts

`PhoneWindowManager` broadcasts Android key press/release events globally for keys that do not already have dedicated system handling. Key repeats are ignored. Volume and mute keys are excluded because they already drive the existing volume/microphone intents below.

```txt
com.amazon.device.intent.action.BUTTON_PRESSED
com.amazon.device.intent.action.BUTTON_RELEASED
```

Extras:

```txt
com.amazon.device.intent.extra.BUTTON_NAME   Android KeyEvent.keyCodeToString(keyCode)
com.amazon.device.intent.extra.KEY_CODE      Android key code
com.amazon.device.intent.extra.SCAN_CODE     Linux scan code
com.amazon.device.intent.extra.DEVICE_ID     Android input device id
```

The physical action/circle button is reported as `KEYCODE_HELP` with scan code `138`.

### Biscuit service actions

`BiscuitService` listens for:

```txt
com.amazon.biscuit.service.BLUETOOTH_PAIRING_MODE
com.amazon.biscuit.service.BLUETOOTH_OFF
com.amazon.biscuit.service.WIFI_ON
com.amazon.biscuit.service.WIFI_OFF
com.amazon.biscuit.service.WIFI_CONNECT      extras: ssid, psk
com.amazon.biscuit.service.VOLUME_UP
com.amazon.biscuit.service.VOLUME_DOWN
com.amazon.biscuit.service.VOLUME_SET        extra: volume
com.amazon.biscuit.service.MICROPHONE_MUTE_ON
com.amazon.biscuit.service.MICROPHONE_MUTE_OFF
com.amazon.biscuit.service.MICROPHONE_MUTE_TOGGLE
```

Microphone mute changes are broadcast as sticky system broadcasts:

```txt
com.amazon.biscuit.service.MICROPHONE_MUTE_CHANGED
com.amazon.biscuit.service.EXTRA_MICROPHONE_MUTED   boolean
```

Android/platform intents consumed by `BiscuitService`:

```txt
android.intent.action.BOOT_COMPLETED
android.media.VOLUME_CHANGED_ACTION
```

Beam/direction ASP investigation and possible future Java-service API: `docs/audio-beam-direction.md`.

## Planning notes

- Tracked sources, patches, scripts, and docs are the source of truth.
- Current bring-up scope: workspace, Docker, preflight, device tree, boot/ADB, WiFi, playback, and microphone.
- Keep Amazon/source/stock extractions unmodified under ignored `workspace/`; express local changes as tracked patches or staged generated files.

## Proprietary blobs

Blobs are not committed. Extract them from the stock OTA into `workspace/vendor/amazon/biscuit/`; `patches/vendor/` records reviewed text deltas before `scripts/stage-tree.sh` copies them into the CM12 checkout.

## Credits and upstreams

This project stands on:

- CyanogenMod/LineageOS CM12.1 and AOSP trees, synced through `manifest/cm12.lock.xml`.
- Amazon OSS `android_device_amazon_mt8163-common`: base MT8163 device-common tree.
- Amazon OSS `android_hardware_amazon`: Amazon hardware helpers.
- Amazon Echo Dot 5.5.5.4 kernel source tarball from Amazon's Fire OS source release.
- Amazon Biscuit stock OTA `272.6.4.1` for proprietary blobs.
- `mt8173-dev/android_device_amazon_sloane` MT8163 `frameworks/av` patch used only as a software FLAC decoder reference, not as a source of OMX MTK integration: https://github.com/mt8173-dev/android_device_amazon_sloane/raw/7a41e2f9314b0b20f49538718e5e515824c2f97d/patches/frameworks/av/0001-mt8163-frameworks-av-add-required-changes-for-mt8163.patch
- MTK helper references from `lbule/android_hardware_mediatek`, used only for comparison of driver-command behavior.
- The amonet Biscuit unlock/recovery work documented in `docs/amonet-biscuit-unlock.md`.

Tracked changes in this repo are the Biscuit-specific glue, patches, scripts, and documentation needed to rebuild the workspace.

## Safety

- Never run `adb shell dd of=/dev/block/...`.
- Do not use stock fastboot for ROM images.
- Do not touch GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc unless explicitly requested.
