# USB gadget scouting — Biscuit

Findings from the Amazon Biscuit kernel (`workspace/kernel/amazon/biscuit`):

- The current kernel exposes the legacy Android USB gadget at `/sys/class/android_usb/android0`.
- Functions present in device sysfs: `adb`, `mtp`, `ptp`, `rndis`, `ecm`, `eem`, `mass_storage`, `acm`, `gser`, `midi`, `audio_source`, `accessory`, `ffs`.
- Observed current state: `functions=adb`, `state=CONFIGURED`.
- `f_audio_source.c` is already integrated into `drivers/usb/gadget/android.c` and appears as `f_audio_source`.
- `audio_source` appears to provide USB audio IN only to the host (Biscuit as a USB microphone): UAC microphone terminal, `USB_DIR_IN` endpoint, and virtual ALSA `USB audio source`.
- Bidirectional speaker + microphone support is available through standalone `CONFIG_USB_AUDIO` / `g_audio` in `drivers/usb/gadget/audio.o`; Kconfig describes UAC2 with virtual USB-OUT and USB-IN ALSA devices.
- The current `biscuit_defconfig` only has `CONFIG_USB_GADGET=y` and `CONFIG_USB_GADGET_BUS_POWERED=y`; it does not enable `CONFIG_USB_AUDIO` / `GADGET_UAC1`.
- No modern configfs `f_uac1/f_uac2` was found; this kernel uses legacy Android gadget sysfs.

Reasonable next milestones:

1. Temporarily test `adb,audio_source` and check whether the host enumerates a USB microphone.
2. Enable `CONFIG_USB_AUDIO=y` and test `g_audio` for bidirectional UAC, knowing that it may compete with `g_android`/ADB.
3. If it works, control sysfs/routing from a `biscuit-ledd`-style daemon with simple IPC to an Android APK/service.
