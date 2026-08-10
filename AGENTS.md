# AGENTS.md

Rules for agents in this repo.

## References

- Amazon help: https://www.amazon.com/gp/help/customer/display.html?nodeId=201626480
- Amazon Echo Dot 5.5.5.4 source: https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/Echo_Dot_src-5.5.5.4-20220824.tar.bz2
- MT8163 frameworks/av FLAC/OMX patch reference: https://github.com/mt8173-dev/android_device_amazon_sloane/raw/7a41e2f9314b0b20f49538718e5e515824c2f97d/patches/frameworks/av/0001-mt8163-frameworks-av-add-required-changes-for-mt8163.patch
- Amazon OSS MT8163 common: https://github.com/amazon-oss/android_device_amazon_mt8163-common
- Amazon OSS hardware helpers: https://github.com/amazon-oss/android_hardware_amazon/tree/cm-12.1
- MTK hardware helper reference: https://github.com/lbule/android_hardware_mediatek
  - Use only to compare/extract small ideas from `wlan/wpa_supplicant_8_lib/mediatek_driver_cmd_nl80211.c` (`lib_driver_cmd_mt66xx`): `COUNTRY`, `GET_STA_STATISTICS`, start/stop/AP if needed.
  - Do not wholesale-replace our Amazon/CM12 helper: its `DRIVER MACADDR` also dereferences `priv` before replying and does not fix the SIGSEGV as-is.
- Biscuit full OTA 272.6.4.1: https://d1s31zyz7dcc2d.cloudfront.net/8811a0fc982bf3331dc54f5aec45d936/update-kindle-full_biscuit-272.6.4.1_user_641575220.bin
- Biscuit amonet notes: `docs/amonet-biscuit-unlock.md`
- Local amonet ignored by git: `workspace/tools/amonet-biscuit-v1.1.0/amonet`
- Root-owned amonet with sudo NOPASSWD only for boot: `/opt/amonet-biscuit-v1.1.0/amonet`

## Agent workflow

- Before every operational action, explicitly say what I am going to do, what I am not going to do, and why.
- If an operation requires `sudo` or root permissions, do not run it: show the exact command for the user to run manually.
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
adb shell biscuit_service usb conference on|off|status
adb shell biscuit_service usb uac2|adb
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
- To flash boot/system, use only TWRP or amonet hacked fastboot.
- Do not use stock fastboot for ROMs: it may be restricted and does not remap amonet partitions.
- Do not touch GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc unless explicitly requested.
- In amonet, the real ROM boot slots are `boot_a_x` / `boot_b_x`; `boot_a` / `boot_b` contain the exploit. TWRP/hacked fastboot do the remapping.
- The user granted sudo NOPASSWD only for `/opt/amonet-biscuit-v1.1.0/amonet/boot-recovery.sh` and `boot-fastboot.sh`. Do not assume permissions for `brick.sh`, `bootrom-step.sh`, `fastboot-step.sh`, or `gpt-fix.sh`.
- Run amonet scripts with stdin closed and logs redirected so tmux is not broken: `sudo -n ./boot-recovery.sh </dev/null >/tmp/amonet-boot-recovery.log 2>&1`.
- If a kernel does not boot and enters a bootloop, the manual-method “unplug and plug back in” step may be resolved by waiting for the next boot cycle.
- Before testing risky USB gadget configs from ADB (for example UAC/g_android changes), arm a short rollback timer first so the device can recover if enumeration drops:
  ```sh
  adb shell 'sh -c "sleep 15; setprop sys.usb.config adb" >/dev/null 2>&1 &'
  adb shell 'setprop sys.usb.config uac2,adb'
  ```
  This helps only if Android keeps running; kernel panic/reboot or hard hangs still require TWRP/rollback.

## Enter TWRP

TWRP is indicated by a blinking/pulsing cyan LED.

Methods:

1. From powered off/unplugged: plug in and, when the blue LED appears, hold the mute/microphone button for about 5s.
2. From Linux with amonet:
   ```sh
   cd /opt/amonet-biscuit-v1.1.0/amonet
   sudo -n ./boot-recovery.sh </dev/null >/tmp/amonet-boot-recovery.log 2>&1
   ```
   Then plug in the device.
3. From hacked fastboot:
   ```sh
   fastboot oem reboot-recovery
   ```
4. From an OS with working ADB:
   ```sh
   adb reboot recovery
   ```

## Enter hacked fastboot

Hacked fastboot is indicated by a rotating rainbow ring.

Methods:

1. From powered off/unplugged: plug in and, about 3s after the blue LED, hold the action/circle button for about 5s.
2. From TWRP:
   ```sh
   adb shell reboot-amonet
   ```
   Important: `adb reboot` does not work for this.
3. From Linux with amonet:
   ```sh
   cd /opt/amonet-biscuit-v1.1.0/amonet
   sudo -n ./boot-fastboot.sh </dev/null >/tmp/amonet-boot-fastboot.log 2>&1
   ```
   Then plug in the device.

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

Always prefer sideload from TWRP. First confirm that ADB sees `recovery` and that `/sbin/twrp` exists; do not rely only on `adb wait-for-device`.

```sh
adb devices -l
adb shell 'command -v twrp; getprop ro.twrp.version'
adb shell twrp sideload
adb sideload update.zip
```

Or confirmed hacked fastboot:

```sh
fastboot getvar all
fastboot flash boot boot.img
fastboot flash system system.img
```

Only if `getvar all` confirms amonet/hacked fastboot. If it looks stock/restricted, stop.
