# Reproducible sources

## CM12

- Manifest: `manifest/cm12.lock.xml`
- Sync: `scripts/sync-cm12.sh`
- Ignored destination: `workspace/cm12/`

## Kernel

- Source: Amazon Echo Dot 5.5.5.4
- URL: `https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/Echo_Dot_src-5.5.5.4-20220824.tar.bz2`
- SHA256: `dd92a7ddd7c0fb9b61455542b84132ad00a445c38ef4f910b1272ac04f6f83dd`
- Materializer: `scripts/prepare-kernel-source.sh`
- Ignored immutable base: `workspace/kernel/amazon/biscuit/`
- Ignored build support: `workspace/kernel/amazon/biscuit-build-support/`
- Ignored build stage: `workspace/kernel/build/biscuit/` via `scripts/stage-kernel-for-build.sh`
- Patches: `patches/kernel/biscuit-kernel-*.patch`

## Biscuit proprietary blobs

- Source: Biscuit full stock OTA 272.6.4.1
- URL: `https://d1s31zyz7dcc2d.cloudfront.net/8811a0fc982bf3331dc54f5aec45d936/update-kindle-full_biscuit-272.6.4.1_user_641575220.bin`
- Generated input: `workspace/extracted/biscuit-stock-272.6.4.1/system.img` from `system.new.dat` + `system.transfer.list`
- Script: `scripts/extract-biscuit-stock-blobs.sh`
- Vendor series: `patches/vendor/`, applied by `scripts/apply-vendor-patches.sh`
- Ignored destination: `workspace/vendor/amazon/biscuit/`

Policy: do not version blobs; extract them from the OTA. The extractor excludes
Mali/GPU and generates `biscuit-vendor.mk`.

## CA certificates

- AOSP project: `https://android.googlesource.com/platform/system/ca-certificates`
- Approved immutable revision: `45c7f199cb11b08f6d1ae2b75da25e53140a0c7d`
- Tracked configuration: `config/ca-certificates.env`
- Materializer: `scripts/update-ca-certs.sh`; creates `workspace/cacerts/`, `workspace/cacerts.pem`, and `workspace/cacerts.source`.
- To update trust, change the reviewed SHA in `config/ca-certificates.env`, review the certificate change, and regenerate the outputs. Branches and mutable refs are not accepted.

## Media and build-variant policy

- MTK OMX and its libraries are not extracted, staged, advertised, or integrated. References to dumps, logs, or binary lists are ABI evidence only; they are never an integration source.
- The Amazon HAL, audio-tuning blobs, and stock tinycompress remain permitted binary dependencies until a validated source replacement exists.
- Google, FFmpeg, and FLAC codecs are built from source. `OMX.google.*` identifies AOSP/CM12 software components, not MTK OMX support.
- Any MTK OMX investigation requires clearly licensed code, verifiable provenance, and demonstrated MT8163/CM12 compatibility. Any future integration needs a separate PRD and Biscuit tests.
- The supported variant remains `userdebug`: insecure ADB/root and permissive SELinux do not constitute a production release. A future `user` build requires Biscuit-specific opt-in for `adbd`, USB policy, and privilege testing; root must not be globally enabled for CM12 `user` products.

## External references used

- Amazon OSS MT8163 common: `https://github.com/amazon-oss/android_device_amazon_mt8163-common`
- Amazon OSS hardware helpers: `https://github.com/amazon-oss/android_hardware_amazon/tree/cm-12.1`
- MT8163 `frameworks/av` software-FLAC reference patch (not a source of OMX MTK integration): `https://github.com/mt8173-dev/android_device_amazon_sloane/raw/7a41e2f9314b0b20f49538718e5e515824c2f97d/patches/frameworks/av/0001-mt8163-frameworks-av-add-required-changes-for-mt8163.patch`
- MTK helper comparison reference: `https://github.com/lbule/android_hardware_mediatek`

## Tracked project work

```txt
device/amazon/biscuit/
device/amazon/mt8163-common/
hardware/amazon/
hardware/mediatek/
patches/cm12/
patches/kernel/
patches/vendor/
scripts/
docker/
```

## Patch dependency map

This table records patches with a concrete Biscuit consumer, ABI, or
configuration. Do not remove one without replacing that dependency and passing
a clean build plus an on-device test where applicable.

| Patch | Dependency preserved |
| --- | --- |
| `cm12-biscuit-frameworks-av-flacdec.patch` | `mt8163-common.mk` installs `libstagefright_soft_flacdec`; the patch also adds the component declared in `media_codecs_google_audio.xml`. |
| `cm12-biscuit-frameworks-av-flacdec-acodec.patch` | FLAC decoder companion: correctly configures `OMX.google.flac.decoder`. |
| `cm12-biscuit-curl-system-cacerts.patch` | `curl` uses the materialized bundle at `/system/etc/security/cacerts.pem`. |
| `cm12-biscuit-use-stock-tinycompress.patch` | The Amazon HAL requires proprietary `libtinycompress.so`; prevents a collision with CM12's source module. |
| `cm12-biscuit-libhardware-legacy-wmtwifi.patch` | Enables/disables the MediaTek `/dev/wmtWifi` device configured by init and ueventd. |
| `cm12-biscuit-wifi-sta-userspace.patch` | Configures wpa_supplicant for the proprietary MediaTek driver and STA-only operation without P2P/AP. |
| `cm12-biscuit-wifi-headless-autoconnect.patch` | A product without a UI needs Wi-Fi enabled and saved-network reconnection at boot. |
| `cm12-biscuit-bluetooth-headless-speaker.patch` | `persist.service.bt.a2dp.sink=true` requires A2DP Sink/AVRCP Controller and automatic connection. |
| `cm12-biscuit-microphone-mute-broadcast.patch` | `BiscuitService` receives `MICROPHONE_MUTE_CHANGED` to reflect microphone state. |
| `cm12-biscuit-framework-mic-mute-key.patch` | Connects physical volume/mute buttons and the documented button-event API for a headless product. |
| `cm12-biscuit-headless-hwui-config.patch` | Makes `ro.config.no_gpu=true` effective; Biscuit does not integrate Mali/GPU blobs. |
| `cm12-biscuit-libcutils-atrace-body.patch` | Amazon/MediaTek blobs import `atrace_*_body` symbols through the ABI. |
| `biscuit-kernel-netfilter-xt-compat-percpu.patch` | Netfilter is enabled in `biscuit_defconfig`; avoids overwriting its per-CPU pointers when replacing tables. |
| `biscuit-kernel-tsl2583-calibrated-lux-kfree.patch` | The TSL2583 ALS driver is enabled; frees the original pointer and avoids an invalid `kfree`. |
| `20-microphone-pga-70.patch` | Microphone-gain calibration documented and covered by the vendor fixture. |

The `lab126_log_write` ABI is also required by proprietary blobs. Keep
`-DAMAZON_LOG` in the build configuration, although the exact place where it is
defined can be reviewed separately.
