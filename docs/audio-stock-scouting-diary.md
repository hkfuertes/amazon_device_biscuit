# Biscuit audio stock scouting diary

Fecha: 2026-07-28  
Rama: `stock-audio-tuning`

## Objetivo

Acercar audio/mic de CM12 a stock Amazon/MTK sin perder reproducibilidad.
Preferencia: compilar cuando se pueda; usar blobs stock solo donde aporten tuning o hardware específico.

## Fuentes revisadas

- OTA stock Biscuit `272.6.4.1`: `workspace/downloads/update-kindle-full_biscuit-272.6.4.1_user_641575220.bin`
- `system.img` extraído: `workspace/extracted/biscuit-ota/system.img`
- Nuevo repo vendor CM14.1:
  - https://github.com/mt8163-dev/android_vendor_amazon_mt8163-common/tree/cm-14.1/
  - Copia local ignorada: `workspace/upstream/android_vendor_amazon_mt8163-common/`
- Scouting local ignorado:
  - `workspace/extracted/audio-scouting/stock/`
  - `workspace/extracted/audio-scouting/mt8163-dev/`
  - manifests: `*.sha256`, `*.sizes`

## Estado actual CM12

El HAL compilado actual (`workspace/hardware/amazon/audio/audio_hw.c`) funciona para bring-up:

- Usa tinyalsa directamente.
- Abre PCM output/input.
- Aplica rutas fijas vía mixer.
- Speaker route incluye `HP Driver Gain Volume`, `Ext_Speaker_Amp_Switch`, etc.
- Mic route configura ADC/MICPGA para ruta fija.

Pero no usa tuning stock:

- No hay `dlopen`/`dlsym`.
- `set_parameters()` es stub.
- `add_audio_effect()`/`remove_audio_effect()` son stubs.
- No llama `libbessound_hd_mtk`, `libaudiocustparam`, `libaudiosetting`, NVRAM/custom params, Dolby, etc.

Conclusión: añadir blobs de tuning alrededor del HAL compilado puede ayudar solo si AudioFlinger/effects framework los carga. El tuning MTK profundo probablemente vive dentro del stock `audio.primary.mt8163.so`.

## Blobs/configs stock encontrados en OTA Biscuit

Candidatos de audio/tuning:

```txt
bin/audioctrl
bin/audioencoderd
bin/audiohub
bin/create_audio_shmbuf.sh
etc/audio_device.xml
etc/audio_effects.conf
etc/audio_init.sh
etc/audio_policy.conf
lib/hw/audio.primary.mt8163.so
lib64/hw/audio.primary.mt8163.so
lib/libamz_nb_audio_flt.so
lib/libaudioctrlutil.so
lib/libaudiocompensationfilter.so
lib/libaudiocomponentengine.so
lib/libaudiocustparam.so
lib/libaudiodcrflt.so
lib/libaudiosetting.so
lib/libbessound_hd_mtk.so
lib/libeffects.so
lib/libtinyalsa.so
lib/soundfx/*
lib64/libaudiocompensationfilter.so
lib64/libaudiocomponentengine.so
lib64/libaudiocustparam.so
lib64/libaudiodcrflt.so
lib64/libaudiosetting.so
lib64/libbessound_hd_mtk.so
lib64/libeffects.so
lib64/libtinyalsa.so
lib64/soundfx/*
```

No meter de primeras:

```txt
lib/libaudioflinger.so
lib/libaudiopolicyservice.so
lib/libaudiopolicymanager*.so
lib64/libaudioflinger.so
lib64/libaudiopolicyservice.so
```

Motivo: riesgo alto de ABI/framework mismatch con CM12.

## Comparación con mt8163-dev vendor CM14.1

El repo nuevo trae 30 ficheros audio-ish. Relevantes:

```txt
proprietary/lib/hw/audio.primary.mt8163.so
proprietary/lib64/hw/audio.primary.mt8163.so
proprietary/lib/libbessound_hd_mtk.so
proprietary/lib64/libbessound_hd_mtk.so
proprietary/lib/libaudiocustparam.so
proprietary/lib64/libaudiocustparam.so
proprietary/lib/libaudiosetting.so
proprietary/lib64/libaudiosetting.so
proprietary/vendor/etc/audio-algorithms/AFE.cfg
proprietary/vendor/etc/audio-algorithms/EQ_2048.cfg
proprietary/vendor/etc/audio-algorithms/MBCL.cfg
proprietary/vendor/etc/audio-algorithms/coefs_FilterBank.cfg
proprietary/vendor/etc/audio_effects.conf
proprietary/vendor/lib/soundfx/libswdap.so
proprietary/lib/soundfx/libaudiofx.so
```

Coinciden por hash con stock Biscuit OTA:

```txt
lib/libbessound_hd_mtk.so
lib/libaudiosetting.so
lib/libaudiocompensationfilter.so
lib/libaudiocomponentengine.so
lib/libaudiodcrflt.so
lib64/libbessound_hd_mtk.so
lib64/libaudiosetting.so
lib64/libaudiocompensationfilter.so
lib64/libaudiocomponentengine.so
lib64/libaudiodcrflt.so
```

Difieren:

```txt
etc/audio_policy.conf
lib/hw/audio.primary.mt8163.so
lib64/hw/audio.primary.mt8163.so
lib/libaudiocustparam.so
lib64/libaudiocustparam.so
```

Preferencia: si existe en OTA Biscuit, usar OTA Biscuit antes que repo externo. Repo externo sirve para configs que no estén en OTA o como pista.

## Señales de tuning real

`libbessound_hd_mtk.so` contiene símbolos/nombres de:

- `Apply_DRC`
- `Apply_Gain`
- `BESLOUDNESS_*`
- filter coefficients
- loudness/DRC/filter-bank logic

`libaudiocustparam.so` contiene:

- default/custom volume params
- gain tables
- speech params
- speaker monitor params
- NVRAM getters/setters

Stock `audio.primary.mt8163.so` contiene:

- `AudioALSAHardware`
- `AudioALSAStreamManager`
- `AudioALSAParamTuner`
- `AudioALSAVolumeController`
- `SetBesLoudnessStatus`
- `OpenSpeakerPath`
- `OpenHeadphonePath`
- `setSmartGain`
- `GetAudioCustomParamFromNV`

Esto apunta a que el tuning más completo está integrado en el HAL stock.

## Pruebas pendientes cuando haya dispositivo

### Experimento A — seguro

Mantener HAL compilado y añadir solo effects/config/libs stock que puedan convivir:

- `etc/audio_effects.conf`
- `lib/soundfx/*`
- `lib/libbessound_hd_mtk.so`
- `lib/libaudiocustparam.so`
- `lib/libaudiosetting.so`
- deps pequeñas `libaudio*filter/component*`

Validar:

```sh
adb shell getprop sys.boot_completed
adb shell logcat -d | grep -Ei 'audio|effect|bessound|audiosetting|audiocust|mediaserver|fatal'
adb shell tinyplay /path/test.wav
adb shell tinycap /cache/mic.wav -D 0 -d 24 -r 16000 -c 1 -b 16 -t 5
```

Resultado esperado: quizá effects cargan; no esperar tuning MTK completo.

### Experimento B — stock HAL mínimo

Usar stock `audio.primary.mt8163.so` desde OTA Biscuit + deps necesarias, sin reemplazar media framework.

Validar primero con build separado/ZIP separado. Riesgo: `mediaserver` crash por ABI/deps.

Log clave:

```sh
adb shell logcat -b all -d | grep -Ei 'audio.primary|AudioALSA|dlopen|cannot link|undefined|mediaserver|fatal'
```

### Experimento C — portar solo knobs mínimos

Si stock HAL no carga y compiled HAL sigue siendo preferible:

- Observar stock boot/logcat para saber qué mixer controls, params y daemons usa.
- Replicar solo controles claros en `audio_hw.c`.
- Evitar reimplementar BesLoudness/Dolby a ciegas.

## Captura stock viva

Dispositivo arrancado en stock y capturado por ADB, solo lectura:

```txt
workspace/extracted/audio-stock-capture-20260728-142910/
```

Contenido útil:

```txt
stock-summary.txt
tinymix-stock.txt
audio_flinger-stock.txt
audio_policy-stock.txt
audio-log-stock.txt
system/audio_policy.conf
system/audio_effects.conf
system/audio_device.xml
system/audio_init.sh
system/audio-algorithms/*
live-system/lib*/... audio .so seleccionados
```

Stock observado:

```txt
ro.build.version.fireos=5.5.5.4
ro.build.version.incremental=272.6.8.0_user_680767620
ro.config.no_gpu=true
ro.hardware=mt8163
ro.mtk_audio_profiles=1
ro.mtk_audio_ape_support=1
sys.audio_init=true
mediaserver running
com.amazon.device.echoaudioservice running
```

Procesos visibles relacionados:

```txt
/system/bin/mediaserver
com.amazon.mediaplayeragent
com.amazon.device.echoaudioservice
com.amazon.alexa.externalmediaplayer.fireos
```

Ficheros stock vivos confirmados:

```txt
/system/etc/audio_device.xml
/system/etc/audio_effects.conf
/system/etc/audio_init.sh
/system/etc/audio_policy.conf
/system/lib/hw/audio.primary.mt8163.so
/system/lib64/hw/audio.primary.mt8163.so
/system/vendor/etc/audio-algorithms/*
```

Hallazgo importante del log stock:

```txt
AudioALSAPlaybackHandlerNormal::open() pcmindex = 23
open config: channels=2 rate=48000 period_size=1536 period_count=2 format=PCM16
ApplyDeviceTurnonSequenceByName DeviceName=ext_speaker_output
cltname = Audio_DacMux_Setting cltvalue = Off
cltname = Right Channel Only cltvalue = On
cltname = HP Driver Gain Volume cltvalue = 6
AudioALSACodecDeviceOutExtSpeakerAmp open
```

Nuestro HAL ya replica parte de esa ruta (`pcm 23`, `Audio_DacMux_Setting`, `Right Channel Only`, `HP Driver Gain Volume`, `Ext_Speaker_Amp_Switch`), pero stock además pasa por `AudioALSAHardwareResourceManager`, device parser/config manager y `AudioALSAStreamOut::setParameters()` con volumen/stream params.

Tinymix stock notable:

```txt
Ext_Speaker_Amp_Switch On
Ext_Amp_Gain 6dB
Audio_DacMux_Setting Off
Right Channel Only On
MFP Gpio Mute On
HP Driver Gain Volume 6 6
ADC_[A-D] Digital Volume Control 88 88
ADC_[A-D] MICPGA Volume Ctrl 40 40
ADC_[A-D] DIF1_L/R Input Gain Off
SpiTimeStamps Off
```

Nota runtime CM12 2026-07-28:

- Copiar `audio_device.xml`, `audio_init.sh`, `audio_policy.conf` y `mtk_omx_core.cfg` desde `system.img` stock eliminó el fallo `mPcm == NULL`; el HAL cargó `audio_device.xml`, abrió `pcmindex = 23` para salida y `pcmindex = 24` para mic.
- Ejecutar `/system/etc/audio_init.sh` aplicó mixers de mic/DAC (`HPL/HPR Output Mixer`, `ADC_[A-D] MICPGA 40 40`, rutas ADC). Después UXPlay sonó.
- `audio_init.sh` intenta crear `/tmp/persistentLedState`; `audio.primary_amazon.mt8163.so` contiene `ledLoop/readLedFile` y monitoriza `/tmp/persistentLedState` con `inotify`. En CM12 `/tmp` no existe y `/` es read-only; queda como warning si audio funciona.
- No crear fix para `/tmp` salvo que falle algo real; si hiciera falta, resolverlo en init/ramdisk y ejecutar `audio_init.sh` en boot.

Comparación stock vivo vs OTA extraída:

```txt
SAME lib/libbessound_hd_mtk.so
SAME lib/libaudiocustparam.so
SAME lib/libaudiosetting.so
SAME lib/libaudiocompensationfilter.so
SAME lib/libaudiocomponentengine.so
SAME lib/libaudiodcrflt.so
SAME lib64 equivalents
DIFF lib/hw/audio.primary.mt8163.so
DIFF lib64/hw/audio.primary.mt8163.so
```

Conclusión nueva: para tuning libs auxiliares, la OTA local sirve. Para stock HAL exacto del dispositivo actual, usar la captura viva si queremos probar ese HAL concreto.

No usar `dd` desde Android.

## Artefacto CM12 validado no-GPU

OTA validada en sesión previa:

```txt
workspace/cm12/out-docker/target/product/biscuit/cm_biscuit-ota-166c656bcf.zip
```

Copia local con nombre humano, ignorada por git:

```txt
workspace/extracted/known-good-otas/cm12-biscuit-known-good-no-gpu-boot-audio-adb-20260728.zip
sha256: 32edca0c92830d26be6882b535fb14bd39a7ee62b1880aba0613712a512ab322
```

## Conclusión provisional: qué falta para sonar como stock

El HAL compilado actual funciona, pero es bring-up: tinyalsa + PCM + mixers fijos. Para sonar como stock probablemente faltan estas capas:

1. Ruta/mixer exacta stock:
   - `pcm 23`, `48000 Hz`, `period_size 1536`, `period_count 2`
   - `ext_speaker_output`
   - `Audio_DacMux_Setting Off`
   - `Right Channel Only On`
   - `HP Driver Gain Volume 6`
   - `Ext_Speaker_Amp_Switch On`
   - `Ext_Amp_Gain 6dB`
   - `MFP Gpio Mute On`

2. Lógica MTK/Amazon dentro del stock HAL:
   - `AudioALSAVolumeController`
   - `AudioALSAParamTuner`
   - `AudioALSAHardwareResourceManager`
   - `AudioALSADeviceConfigManager`
   - `SetBesLoudnessStatus`
   - custom params/NVRAM/gain tables

3. Tuning/effects auxiliares:
   - `libbessound_hd_mtk.so`
   - `libaudiocustparam.so`
   - `libaudiosetting.so`
   - `audio_effects.conf`
   - `vendor/etc/audio-algorithms/*`
   - `libswdap.so` / Dolby, si alguna ruta lo activa

Hipótesis actual: para un sonido realmente stock, el mayor salto es probar `audio.primary.mt8163.so` stock + deps. Mantener HAL compilado permite mejorar ruta/gain básica, pero no activa por sí solo BesLoudness/custom params.

## Comparativa Lineage18 / Spot posible

Si el usuario arranca Lineage18 u otra ROM MT8163/Amazon, capturar lo mismo que stock:

```sh
adb devices -l
adb shell getprop | grep -Ei 'audio|media|mtk|af|dolby|bes|ro\.build|ro\.product|ro\.hardware|ro\.config'
adb shell ps | grep -Ei 'audio|media|aud|dolby|hub|ctrl'
adb shell tinymix > /sdcard/tinymix-lineage18.txt
adb shell dumpsys media.audio_flinger > /sdcard/audio_flinger-lineage18.txt
adb shell dumpsys media.audio_policy > /sdcard/audio_policy-lineage18.txt
adb shell logcat -b all -d | grep -Ei 'AudioALSA|audio|bessound|dolby|swdap|audiosetting|audiocust|audiohub|audioctrl|mediaserver|fatal|cannot link|dlopen' > /sdcard/audio-log-lineage18.txt
```

Comparar contra stock vivo:

```txt
workspace/extracted/audio-stock-capture-20260728-142910/
```

Objetivo de la comparativa: saber si Lineage18 usa HAL stock, HAL MTK portado o HAL source propio, y qué piezas mínimas necesita para audio/mic funcional.

## Scouting Rook Lineage18 aprobado

Repos:

```txt
https://github.com/amazon-oss/android_device_amazon_rook
https://github.com/amazon-oss/android_vendor_amazon_rook
https://github.com/amazon-oss/android_hardware_amazon/tree/lineage-18.1/audio/hal
```

Hallazgo clave: Rook no reimplementa el audio MTK desde cero. Compila un wrapper Lineage/AOSP y conserva el HAL Amazon/MTK propietario debajo.

Device `lineage-18.1`:

```txt
PRODUCT_PACKAGES += \
    android.hardware.audio@2.0-impl \
    android.hardware.audio.effect@2.0-impl \
    audio.primary.amazon_wrapper

PRODUCT_PACKAGES += \
    libaudio-resampler \
    libaudioutils \
    libaudioroute \
    libtinyalsa \
    libamazonlog \
    libbinder_shim \
    libcutils_shim

PRODUCT_COPY_FILES += \
    configs/audio_policy_configuration.xml:vendor/etc/audio_policy_configuration.xml
```

Vendor Rook copia:

```txt
vendor/lib/hw/audio.primary_amazon.mt8163.so
vendor/lib/libaudiocompensationfilter.so
vendor/lib/libaudiocomponentengine.so
vendor/lib/libaudiocustparam.so
vendor/lib/libaudiodcrflt.so
vendor/lib/libaudiosetting.so
vendor/lib/libaudiostream.so
vendor/lib/libaudiostream_jni.so
vendor/lib/libbessound_hd_mtk.so
vendor/lib/libcustom_nvram.so
vendor/etc/audio-algorithms/*
etc/audio_device.xml
```

Wrapper `audio.primary.amazon_wrapper` vive en `android_hardware_amazon/audio/hal` y hace:

```txt
hw_get_module_by_class(AUDIO_HARDWARE_MODULE_ID, "primary_amazon", ...)
amazon_module->methods->open(..., &adev->amazon_device)
```

Luego delega casi todo:

```txt
open_output_stream -> amazon_device->open_output_stream
open_input_stream  -> amazon_device->open_input_stream
set_parameters     -> amazon_device->set_parameters
set_master_volume  -> amazon_device->set_master_volume
set_mic_mute       -> amazon_device->set_mic_mute
create_audio_patch -> amazon_device->create_audio_patch
```

Tiene compat layer para input legacy y propiedad opcional:

```txt
ro.audiohal.has_get_capture_position
```

Conclusión para Biscuit: si queremos "compilar siempre que se pueda" y sonar stock, el patrón aprobado no es portar BesLoudness a mano. Es compilar un wrapper/shim y poner debajo el blob Amazon/MTK stock renombrado como `audio.primary_amazon.mt8163.so` con sus deps/tuning. Para CM12 habría que adaptar el wrapper a Make/headers HAL antiguos o escribir una versión mínima C/C++ CM12 que delegue al blob stock.
