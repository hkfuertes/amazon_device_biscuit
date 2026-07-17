# amonet Biscuit unlock notes

Source forum attachment: https://xdaforums.com/attachments/amonet-biscuit-v1-1-0-zip.6331296/

## Scope

- Only for 2nd gen Echo Dot / Biscuit / RS03QR, released in 2016.
- Current release noted by source: `amonet-biscuit-v1.1.0.zip`.
- Unlock modifies GPT and wipes userdata.
- If already unlocked, update by flashing the current amonet ZIP in TWRP.

## Host requirements

- Linux or live Linux system, Ubuntu recommended.
- MicroUSB cable.
- Ubuntu/Debian packages:

```sh
sudo apt update
sudo add-apt-repository universe
sudo apt install python3 python3-serial adb fastboot dos2unix
sudo systemctl stop ModemManager
sudo systemctl disable ModemManager
```

## Firmware requirement before unlock

- Recommended: update device to latest FireOS 6 version first.
- Supported version called out by source: Fire OS 6.5.7.0 `NS6570/6077`, version code `12383141252`.
- If current firmware is not that, update via OTA before unlock.

## Unlock flow summary

1. Download latest amonet package.
2. Extract ZIP and open terminal in extracted folder.
3. Enter fastboot from powered-off state: reconnect power while holding action/circle button until green LED.
4. If fastboot works, skip brick step and continue to bootrom/fastboot steps.
5. If fastboot is unavailable/bricked, disassemble and use hardware shorting method.
6. Run `sudo ./brick.sh` only when following the amonet instructions; success shows rainbow LED ring, then unplug.
7. Run `sudo ./bootrom-step.sh`, then connect device.
8. If brick step failed or unsupported version appears, short the pin while unplugged, start `bootrom-step.sh`, connect, and hold short until script says release.
9. When script finishes, device should reboot to hacked fastboot, shown by spinning rainbow LED ring.
10. Run `sudo ./fastboot-step.sh` and press enter.
11. Successful unlock boots to TWRP, shown by blinking/pulsing cyan LED.

## Post-unlock stock firmware install

Place chosen stock firmware and `f1r30s.zip` in the same folder, then:

```sh
adb shell twrp wipe data
adb shell twrp wipe cache
adb push f1r30s.zip /sdcard/
adb shell twrp sideload
adb sideload update.bin
adb shell twrp install /sdcard/f1r30s.zip
```

- Green pulse indicates each ZIP install succeeded.
- Always flash `f1r30s.zip` after stock firmware; otherwise OS will not boot.
- Once exploit is installed, only Fire OS 5 based ROMs boot; Fire OS 6 may soft-brick.
- `f1r30s.zip` enables ADB and UART, blocks OTA domains, disables dm-verity.

## Known stock firmware filenames

- `update-kindle-full_biscuit-272.5.6.4_user_564196920.bin` — Fire OS 5.5.0.3 `564196920`
- `update-kindle-full_biscuit-272.6.4.1_user_641575220.bin` — Fire OS 5.5.3.1 `641575220`
- `update-kindle-csm_biscuit-272.6.6.6_user_666694320.bin` — FireOS 5.5.4.6 `666694320`
- `update-kindle-csm_biscuit-272.6.7.2_user_672720020.bin` — Fire OS 5.5.4.9 `672720020`
- `update-kindle-csm_biscuit-272.6.7.3_user_673726720.bin` — Fire OS 5.5.5.0 `673726720`
- `update-kindle-csm_biscuit-272.6.8.0_user_680767620.bin` — Fire OS 5.5.5.4 `680767620`

## TWRP interaction

TWRP indicator: pulsating/blinking cyan LED.

Enter TWRP by:

- From unplugged: connect power; when blue LED appears, hold mute/microphone about 5 seconds.
- From host: run `sudo ./boot-recovery.sh`, then connect device.
- From hacked fastboot rainbow ring: `fastboot oem reboot-recovery`.
- From running OS: `adb reboot recovery`.

TWRP CLI examples:

```sh
twrp wipe data
twrp install /sdcard/update.zip
adb shell twrp sideload
adb sideload update.zip
```

## Hacked fastboot interaction

Hacked fastboot indicator: spinning rainbow LED ring.

Enter hacked fastboot by:

- From unplugged: connect power; about 3 seconds after blue LED, hold action/circle about 5 seconds.
- From TWRP: `adb shell reboot-amonet`.
- From running OS: no direct method; use another entry method.

## Important partition notes

- Device uses A/B partitioning.
- If neither slot contains bootable OS and repeated boot attempts exhaust counters, Preloader may brick the device.
- In the new partition scheme, real boot images live in `boot_a_x` / `boot_b_x`.
- `boot_a` / `boot_b` hold the exploit.
- TWRP and hacked fastboot remap this, so installing ZIPs/images from TWRP or hacked fastboot works as expected.
- Do not flash boot/recovery images from FireOS tools like FlashFire or MagiskManager. If doing so anyway, target `boot_a_x` / `boot_b_x`.
- TWRP blocks updates from overwriting LK/Preloader/TZ.
- Full updates should work; incremental updates will not.

## UART

- UART access is available via C7 pad RX.
- Exploit forcibly enables UART on every boot.

## Source code references

- https://github.com/R0rt1z2/amonet/tree/mt8163-biscuit
- https://github.com/amazon-oss/android_bootable_recovery
- https://github.com/R0rt1z2/twrp_device_amazon_biscuit

## Credits from source post

- `@k4y0z` — initial amonet port for Biscuit.
- `@Rortiz2`
- `@xyz` — original amonet exploit for karnak.
- AntiEngineer — development board, pins, UART.
