# AGENTS.md

Rules for agents in this repo.

## Language

- All repository copy and documentation must be written in English. Preserve literal command output, identifiers, and quoted upstream text when translation would change their meaning.

## References

- Amazon help: https://www.amazon.com/gp/help/customer/display.html?nodeId=201626480
- Amazon Echo Dot 5.5.5.4 source (CM12 kernel): https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/Echo_Dot_src-5.5.5.4-20220824.tar.bz2
- Amazon Echo Dot 6.5.7.1 source (CM14.1 baseline; comparison build remains as-is): https://fireos-audio-src.s3.amazonaws.com/dMUQiRDxI3hFuRDaF0WTumrp71/Echo_Dot_src-6.5.7.1-20251024.tar.bz2
- Biscuit/Puffin Fire OS 6.5.7.4 audio blob source: https://d1s31zyz7dcc2d.cloudfront.net/2026/8/3/f49aaff7-dd63-4d9c-9e9a-c17498267de5/update-kindle-biscuit_puffin-NS6574_user_7623_0013121734532.bin
- MT8163 frameworks/av FLAC/OMX patch reference: https://github.com/mt8173-dev/android_device_amazon_sloane/raw/7a41e2f9314b0b20f49538718e5e515824c2f97d/patches/frameworks/av/0001-mt8163-frameworks-av-add-required-changes-for-mt8163.patch
- Amazon OSS MT8163 common: https://github.com/amazon-oss/android_device_amazon_mt8163-common
- Amazon OSS hardware helpers: https://github.com/amazon-oss/android_hardware_amazon/tree/cm-12.1
- MTK hardware helper reference: https://github.com/lbule/android_hardware_mediatek
  - Use only to compare/extract small ideas from `wlan/wpa_supplicant_8_lib/mediatek_driver_cmd_nl80211.c` (`lib_driver_cmd_mt66xx`): `COUNTRY`, `GET_STA_STATISTICS`, start/stop/AP if needed.
  - Do not wholesale-replace our Amazon/CM12 helper: its `DRIVER MACADDR` also dereferences `priv` before replying and does not fix the SIGSEGV as-is.
- Biscuit full OTA 272.6.4.1: https://d1s31zyz7dcc2d.cloudfront.net/8811a0fc982bf3331dc54f5aec45d936/update-kindle-full_biscuit-272.6.4.1_user_641575220.bin
- Biscuit amonet v2 notes and observed TWRP contract: `docs/amonet-biscuit-unlock.md`
- amonet v1.1.0 helper paths and GPT aliases are historical only; do not use them with v2.

## Agent workflow

- Before every operational action, explicitly say what I am going to do, what I am not going to do, and why.
- Do not run `sudo` or any host-root operation. Show the exact command for the user to run manually.
- On this device, `adb wait-for-device` can hang or be a poor progress signal. Prefer explicit checks with `adb devices -l`, visual LED/TWRP state, and short timeouts; if ADB does not appear, stop and report.
- Unless explicitly requested by the user, do not poll or wait for long periods. Long builds/flashes/reboots must be launched detached or as a single concrete action, with instructions for monitoring, then return control so the user can ask between steps.
- Any change under `workspace/cm12` must be reproducible from tracked repo files: prefer `patches/*.patch`, `scripts/stage-tree.sh`, `scripts/apply-patches.sh`, or equivalent scripts. Do not leave manual-only changes in `workspace/cm12`.

## Biscuit service helper

Current builds include `/system/bin/biscuit_service`, a shell-friendly wrapper around the Biscuit Android service. Prefer it over ad-hoc Java probes for supported device actions.

Known commands:

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

Notes:

- Do not print WiFi PSKs in responses/log summaries.
- `wifi on` reconnects a saved network; `wifi connect` saves/connects WPA-PSK or open networks.
- Use this for WiFi reconnect after data wipe/OTA before falling back to `scripts/wifi/*.java`.

## TODOs

- Enable USB gadgets in the kernel, ideally all required ones, specifically USB audio out/in, for a future APK that turns Biscuit into a conference speaker/microphone.
- Tune microphone gain and speaker EQ for better voice/audio quality.
- Future mega-TODO: investigate moving to Android 7 / CM14.1 with a 6.5.x kernel for Biscuit. Treat as a separate line of work; do not mix with current CM12 stabilization.

## Device safety

- Never write partitions with `dd` from Android/ADB. No:
  - `adb shell dd of=/dev/block/...`
  - `adb exec-in dd of=/dev/block/...`
- Use confirmed TWRP sideload for ROM updates. amonet v2 has no verified project fastboot workflow.
- Do not touch GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc unless explicitly requested.
- amonet v2 leaves the GPT native: ROM slots are `boot_a` / `boot_b` and `system_a` / `system_b`; `boot_a_x` / `boot_b_x` do not exist.
- CM runtime fstab must use `slotselect` and `/dev/block/platform/bootdevice/by-name/{boot,system}`. Legacy recovery block OTAs must instead target TWRP's live `/dev/block/current-boot` and `/dev/block/current-system` aliases; edify does not apply `slotselect`. Do not hard-code a v1 alias or assume one recovery ZIP populates both slots.
- The official v2 Fire OS procedure installs the ROM twice. Confirm the current slot and inspect the OTA updater before every custom-ROM installation.
- If a kernel does not boot and enters a bootloop, the manual-method “unplug and plug back in” step may be resolved by waiting for the next boot cycle.

## Enter TWRP

TWRP is indicated by a blinking/pulsing cyan LED.

- From an OS with working ADB: `adb reboot recovery`.
- The v2 announcement says that, with USB connected, holding only MUTE while connecting power enters Preloader USBDL recovery. Consult the upstream Important Notes for its complete procedure.
- Do not use v1 `boot-recovery.sh`, `boot-fastboot.sh`, `reboot-amonet`, fastboot, or old button timing instructions with v2.

## Build CM12

Native local builds fail due to legacy Python 2. Use Docker.

To build/generate an OTA in the background, always use detached Docker so the user can keep typing and monitor it:

```sh
docker rm -f cm12-biscuit-build >/dev/null 2>&1 || true
docker run -d --name cm12-biscuit-build \
  -v "$PWD:$PWD" \
  -w "$PWD/workspace/cm12" \
  cm12-ubuntu14:latest \
  bash -lc 'source build/envsetup.sh >/dev/null && lunch cm_biscuit-userdebug && export OUT_DIR="$PWD/out-docker" && export PATH="$OUT_DIR/host/linux-x86/bin:$PATH" && make -j$(nproc) otapackage'
```

Notes:

- `OUT_DIR` must be absolute (`$PWD/out-docker` inside `workspace/cm12`); `OUT_DIR=out-docker` breaks recovery because of relative paths.
- If `hostapd` flags change, clean its intermediates from Docker because `out-docker` is root-owned.
- For any long build/OTA/compilation, do not run in the foreground: use the fixed `cm12-biscuit-build` container with `docker run -d`.

## Related repos

- `../cm12-biscuit` is read/learn-only. Do not dirty it.
- Do not copy anything as-is from `../cm12-biscuit` without explicit permission from the user.

## Recommended flashing

Always prefer sideload from confirmed amonet v2 TWRP. First confirm recovery,
TWRP version, and the active slot; do not rely only on `adb wait-for-device`.

```sh
adb devices -l
adb shell 'command -v twrp; getprop ro.twrp.version; getprop ro.boot.slot_suffix'
adb shell twrp sideload
adb sideload update.zip
```

Do not use fastboot or a v1 partition alias. Before any custom-ROM install,
inspect the generated updater and confirm it contains no GPT, preloader, LK,
TZ, recovery, userdata, cache, persist, or misc operation. The v2 official ROM
procedure uses two installations to populate both slots; do not claim the same
behavior for a custom OTA until it is verified.
