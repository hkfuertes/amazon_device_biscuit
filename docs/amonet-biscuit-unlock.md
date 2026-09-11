# amonet Biscuit v2.0.0 notes

## Scope and source

- Device: Echo Dot 2nd generation / Biscuit / RS03QR.
- Current project baseline: `amonet-biscuit-v2.0.0.zip`.
- Source: user-provided copy of the updated amonet announcement, recorded on
  2026-09-11. Consult the current upstream OP for the complete unlock and
  button-mode procedure.
- v2 uses a new Preloader exploit, removes `lk-payload`, leaves the GPT
  unmodified, supports Fire OS 6, and drops Fire OS 5 support.
- TWRP is updated to 3.7.0_9-0. Windows support and Preloader USBDL recovery
  are new to v2.

## Observed v2 recovery contract

Captured from the connected Biscuit in TWRP 3.7.0_9-0 on 2026-09-11:

- `ro.boot.slot_suffix=_a`.
- `/dev/block/current-boot` points to `mmcblk0p10` (`boot_a`).
- `/dev/block/current-system` points to `mmcblk0p13` (`system_a`).
- `/dev/block/platform/bootdevice` points to
  `/dev/block/platform/soc/11230000.mmc`.
- The native GPT has no `boot_a_x` or `boot_b_x` entries and no
  `/dev/block/platform/soc/by-name` directory.

| GPT entry | Block node | Size |
| --- | --- | --- |
| `boot_a` | `mmcblk0p10` | 16 MiB |
| `boot_b` | `mmcblk0p11` | 16 MiB |
| `recovery` | `mmcblk0p12` | 16 MiB |
| `system_a` | `mmcblk0p13` | 768 MiB |
| `system_b` | `mmcblk0p14` | 768 MiB |
| `cache` | `mmcblk0p15` | 784 MiB |
| `userdata` | `mmcblk0p16` | 1,325,383,168 bytes |

TWRP maps `/boot` and `/system_root` through its `current-*` aliases, then
also exposes explicit per-slot entries. This proves the active-slot mapping in
that recovery session; it does **not** prove that an arbitrary update ZIP
populates both slots automatically.

The observed GPT has no `metadata` by-name entry. Keep the inherited CM
userdata-encryption policy unchanged until a boot failure or a Fire OS source
comparison establishes the correct replacement.

## Updating from amonet v1

The v2 announcement requires applying `amonet-biscuit-v2.0.0.zip` through
TWRP and not interrupting its reboot into the new recovery:

```sh
adb push amonet-biscuit-v2.0.0.zip /sdcard/
adb shell twrp install /sdcard/amonet-biscuit-v2.0.0.zip
```

v2 uses Fire OS 6 firmware. The announcement directs users to wipe cache and
data, install the current Fire OS 6 update, reboot recovery, then install the
same update again. The second installation is required to populate both A/B
slots. Treat those wipes and installations as explicit user-controlled device
operations.

## Custom ROM contract

CM14 uses Android's standard `slotselect` fstab flag with the native base paths
`/dev/block/platform/bootdevice/by-name/system` and `.../boot`. CM14 fs_mgr
appends `ro.boot.slot_suffix` at runtime, yielding `system_a`/`boot_a` or
`system_b`/`boot_b` without an amonet-specific remapping layer.

A legacy edify/block recovery OTA does not invoke fs_mgr, so `slotselect` alone
cannot select its write target. The live v2 TWRP fstab defines
`/dev/block/current-system` and `/dev/block/current-boot`; generated CM14
recovery OTAs must use those aliases. TWRP's `bcbtool` updates them from the
active BCB slot. Verify the slot before each of the two installations rather
than assuming that rebooting recovery changes it automatically.

Do not use `boot_a_x`, `boot_b_x`, `_amonet` aliases, or v1 GPT assumptions.
Do not assume a single custom recovery-OTA installation fills both slots:
preflight its updater script and follow the v2 two-install rule only when that
artifact's slot behavior has been verified.

Read-only slot checks in TWRP:

```sh
adb shell 'getprop ro.twrp.version; getprop ro.boot.slot_suffix; ls -l /dev/block/current-boot /dev/block/current-system'
```

## Recovery and fastboot

- From a running Android system, `adb reboot recovery` remains the verified
  entry method.
- With USB connected, holding only MUTE while connecting power enters the new
  Preloader USBDL recovery mode according to the v2 announcement. Consult the
  current upstream Important Notes for the complete procedure.
- v2 removes stock non-hacked fastboot. This repository has no verified v2
  fastboot flashing workflow; use confirmed TWRP sideload instead.
- The v1 `boot-recovery.sh`, `boot-fastboot.sh`, `reboot-amonet`, and old
  button timing instructions are historical only and must not be used for v2.
