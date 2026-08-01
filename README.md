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

## Biscuit intents

Current builds expose these system intents for APKs and shell helpers.

### Button broadcasts

`PhoneWindowManager` broadcasts key presses/releases globally for keys that do not already have dedicated system handling. Volume and mute keys are excluded because they already drive the existing volume/microphone intents below.

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

## Proprietary blobs

Blobs are not committed. Extract them from the stock OTA into `workspace/vendor/amazon/biscuit/`; `scripts/stage-tree.sh` copies them into the CM12 checkout.

## Credits and upstreams

This project stands on:

- CyanogenMod/LineageOS CM12.1 and AOSP trees, synced through `manifest/cm12.lock.xml`.
- Amazon OSS `android_device_amazon_mt8163-common`: base MT8163 device-common tree.
- Amazon OSS `android_hardware_amazon`: Amazon hardware helpers.
- Amazon Echo Dot 5.5.5.4 kernel source tarball from Amazon's Fire OS source release.
- Amazon Biscuit stock OTA `272.6.4.1` for proprietary blobs.
- `mt8173-dev/android_device_amazon_sloane` MT8163 `frameworks/av` patch used as the reference for the software FLAC decoder / OMX work: https://github.com/mt8173-dev/android_device_amazon_sloane/raw/7a41e2f9314b0b20f49538718e5e515824c2f97d/patches/frameworks/av/0001-mt8163-frameworks-av-add-required-changes-for-mt8163.patch
- MTK helper references from `lbule/android_hardware_mediatek`, used only for comparison of driver-command behavior.
- The amonet Biscuit unlock/recovery work documented in `docs/amonet-biscuit-unlock.md`.

Tracked changes in this repo are the Biscuit-specific glue, patches, scripts, and documentation needed to rebuild the workspace.

## Safety

- Never run `adb shell dd of=/dev/block/...`.
- Do not use stock fastboot for ROM images.
- Do not touch GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc unless explicitly requested.
