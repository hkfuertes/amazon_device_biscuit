# USB gadget scouting — Biscuit

Findings rápidos del kernel Amazon Biscuit (`workspace/kernel/amazon/biscuit`):

- El kernel actual expone Android USB gadget legacy en `/sys/class/android_usb/android0`.
- Funciones presentes en sysfs del dispositivo: `adb`, `mtp`, `ptp`, `rndis`, `ecm`, `eem`, `mass_storage`, `acm`, `gser`, `midi`, `audio_source`, `accessory`, `ffs`.
- Estado actual visto: `functions=adb`, `state=CONFIGURED`.
- `f_audio_source.c` ya está integrado en `drivers/usb/gadget/android.c` y aparece como `f_audio_source`.
- `audio_source` parece ser solo USB audio IN hacia el host (Biscuit como micrófono USB): terminal UAC microphone, endpoint `USB_DIR_IN`, ALSA virtual `USB audio source`.
- Para speaker + mic bidireccional hay `CONFIG_USB_AUDIO` / `g_audio` standalone en `drivers/usb/gadget/audio.o`; Kconfig dice UAC2 con USB-OUT y USB-IN virtual ALSA.
- `biscuit_defconfig` actual solo tiene `CONFIG_USB_GADGET=y` y `CONFIG_USB_GADGET_BUS_POWERED=y`; no habilita `CONFIG_USB_AUDIO` / `GADGET_UAC1`.
- No se vio configfs moderno `f_uac1/f_uac2`; este kernel usa gadget Android legacy sysfs.

Próximos hitos razonables:

1. Probar temporalmente `adb,audio_source` y ver si el host enumera un micrófono USB.
2. Habilitar `CONFIG_USB_AUDIO=y` y probar `g_audio` para UAC bidireccional, sabiendo que puede competir con `g_android`/ADB.
3. Si funciona, controlar sysfs/routing desde un daemon tipo `biscuit-ledd` + IPC simple hacia APK/servicio Android.
