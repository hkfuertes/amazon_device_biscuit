# AGENTS.md

Rules for agents in this repo.

## Language

- All repository copy and documentation must be written in English. Preserve literal command output, identifiers, and quoted upstream text when translation would change their meaning.

## References

- Amazon help: https://www.amazon.com/gp/help/customer/display.html?nodeId=201626480
- Amazon Echo Dot 6.5.7.1 source: https://fireos-audio-src.s3.amazonaws.com/dMUQiRDxI3hFuRDaF0WTumrp71/Echo_Dot_src-6.5.7.1-20251024.tar.bz2
- Biscuit/Puffin Fire OS 6.5.7.4 OTA source: https://d1s31zyz7dcc2d.cloudfront.net/2026/8/3/f49aaff7-dd63-4d9c-9e9a-c17498267de5/update-kindle-biscuit_puffin-NS6574_user_7623_0013121734532.bin
- Biscuit full OTA 272.6.4.1, used only as the verified stock source for the headless HWC blob: https://d1s31zyz7dcc2d.cloudfront.net/8811a0fc982bf3331dc54f5aec45d936/update-kindle-full_biscuit-272.6.4.1_user_641575220.bin
- MT8163-dev common reference: https://github.com/mt8163-dev/android_device_amazon_mt8163-common/tree/cm-14.1
- Amazon OSS MT8163 common: https://github.com/amazon-oss/android_device_amazon_mt8163-common
- Biscuit amonet v2 notes and observed TWRP contract: `docs/amonet-biscuit-unlock.md`

## Agent workflow

- Before every operational action, explicitly say what I am going to do, what I am not going to do, and why.
- Do not run `sudo` or any host-root operation. Show the exact command for the user to run manually.
- On this device, `adb wait-for-device` can hang or be a poor progress signal. Prefer explicit checks with `adb devices -l`, visual LED/TWRP state, and short timeouts; if ADB does not appear, stop and report.
- Unless explicitly requested by the user, do not poll or wait for long periods. Long builds/flashes/reboots must be launched detached or as a single concrete action, with instructions for monitoring, then return control so the user can ask between steps.
- Any change under `workspace/cm14.1` must be reproducible from tracked repo files: prefer `patches/*.patch`, `scripts/stage-tree.sh`, `scripts/apply-patches.sh`, or equivalent scripts. Do not leave manual-only changes in `workspace/cm14.1`.

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

- Do not print Wi-Fi PSKs in responses or log summaries.
- `wifi on` reconnects a saved network; `wifi connect` saves/connects WPA-PSK or open networks.

## TODOs

- Keep the full product stable before starting any framework-free minimal product work.
- Tune microphone gain and speaker EQ for better voice/audio quality.
- Investigate Amazon/MediaTek ASP as a separate microphone/speaker improvement line.
- USB gadget work is intentionally out of scope until the user asks for it.

## Device safety

- Never write partitions with `dd` from Android/ADB. No:
  - `adb shell dd of=/dev/block/...`
  - `adb exec-in dd of=/dev/block/...`
- Use confirmed amonet v2 TWRP sideload for ROM updates. amonet v2 has no verified project fastboot workflow.
- Do not touch GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc unless explicitly requested.
- amonet v2 leaves the GPT native: ROM slots are `boot_a` / `boot_b` and `system_a` / `system_b`; `boot_a_x` / `boot_b_x` do not exist.
- Runtime fstab must use `slotselect` and `/dev/block/platform/bootdevice/by-name/{boot,system}`. Recovery block OTAs must instead target TWRP's live `/dev/block/current-boot` and `/dev/block/current-system` aliases; edify does not apply `slotselect`.
- The official v2 Fire OS procedure installs the ROM twice. Confirm the current slot and inspect the OTA updater before every custom-ROM installation.
- If a kernel does not boot and enters a bootloop, the manual-method “unplug and plug back in” step may be resolved by waiting for the next boot cycle.

## Enter TWRP

TWRP is indicated by a blinking/pulsing cyan LED.

- From Android with working ADB: `adb reboot recovery`.
- With USB connected, holding only MUTE while connecting power enters Preloader USBDL recovery on amonet v2. Consult upstream notes for the full procedure.
- Do not use v1 helper scripts, `reboot-amonet`, fastboot, or old button timing instructions with v2.

## Build

Native local builds are not supported. Use Docker and the root scripts.

```sh
scripts/sync.sh
make full
docker logs -f cm14.1-biscuit-build
```

Notes:

- `make full` is a thin alias for `scripts/build.sh`, which launches a detached `cm14.1-biscuit-build` container.
- `OUT_DIR` is absolute inside `workspace/cm14.1`.
- For long build/OTA/compilation work, do not run in the foreground unless the user explicitly asks.

## Recommended flashing

Always prefer sideload from confirmed amonet v2 TWRP. First confirm recovery,
TWRP version, and the active slot; do not rely only on `adb wait-for-device`.

```sh
adb devices -l
adb shell 'command -v twrp; getprop ro.twrp.version; getprop ro.boot.slot_suffix'
adb shell twrp sideload
adb sideload update.zip
```

Before any custom-ROM install, inspect the generated updater and confirm it contains no GPT, preloader, LK, TZ, recovery, userdata, cache, persist, misc, `dd`, or stale by-name boot/system write. The expected custom OTA writes are only `/dev/block/current-system` and `/dev/block/current-boot`.
