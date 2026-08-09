# USB gadget scouting — Biscuit

Findings rápidos del kernel Amazon Biscuit (`workspace/kernel/amazon/biscuit`):

- El kernel actual expone Android USB gadget legacy en `/sys/class/android_usb/android0`.
- Funciones presentes en sysfs del dispositivo: `adb`, `mtp`, `ptp`, `rndis`, `ecm`, `eem`, `mass_storage`, `acm`, `gser`, `midi`, `audio_source`, `accessory`, `ffs`.
- Estado base visto: `functions=adb`, `state=CONFIGURED`.
- `f_audio_source.c` ya está integrado en `drivers/usb/gadget/android.c` y aparece como `f_audio_source`.
- `audio_source` es USB audio IN hacia el host (Biscuit como micrófono USB): terminal UAC microphone, endpoint `USB_DIR_IN`, ALSA virtual `USB audio source`.
- Validado: `biscuit_service usb mic on` cambia a `audio_source,adb`; el host Linux enumera `18d1:2d03 Android Open Accessory device (audio + ADB)` y `/proc/asound/pcm` muestra `USB Audio : capture 1`.
- Primera versión de datos: `biscuit_usb_mic_bridge` copia mic físico `card0,dev24` 16 kHz/9ch/S24_3LE hacia `audio_source` 44.1 kHz/stereo/S16_LE con resampling nearest-neighbor mínimo. `biscuit_service usb mic on` lo arranca si el binario existe; `off` lo mata y restaura `adb`.
- Validado con binario temporal en `/data/local/tmp`: `ffmpeg -f alsa -channels 2 -sample_rate 44100 -i hw:1,0 -t 2 ...` capturó WAV 44.1 kHz/stereo (~345 KiB, RMS bajo pero no cero en silencio: ~12, peak ~51).
- Para speaker + mic bidireccional el Kconfig anuncia `CONFIG_USB_AUDIO` / `g_audio` standalone, pero aquí no es plug-and-play: está en un `choice` con `CONFIG_USB_G_ANDROID=y`, así que `oldconfig` descarta `CONFIG_USB_AUDIO=m`; además el árbol no trae `drivers/usb/gadget/audio.c` aunque el Makefile referencia `audio.o`.
- `biscuit_defconfig` actual tiene `CONFIG_USB_GADGET=y`, `CONFIG_USB_GADGET_BUS_POWERED=y`, `CONFIG_USB_G_ANDROID=y`; no puede habilitar `CONFIG_USB_AUDIO` simultáneamente sin parchear Kconfig/fuentes y resolver la convivencia con ADB.
- No se vio configfs moderno `f_uac1/f_uac2`; este kernel usa gadget Android legacy sysfs.

Próximos hitos razonables:

1. Probar con voz cerca del dispositivo y ajustar ganancia/canal si el nivel USB queda bajo.
2. Para speaker USB, decidir entre: parchear `g_android` con una función UAC OUT, o portar `g_audio` completo y alternar fuera de ADB. No dejar `CONFIG_USB_AUDIO=m` suelto: Kconfig lo descarta.
3. Si hay USB OUT, añadir segundo bridge tinyalsa para USB OUT → speaker físico.
