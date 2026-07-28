# Handoff — Biscuit CM12 no_gpu + audio/UXPlay debug

## Repo / estado
- Repo: `/home/hkfuertes/projects/amazon_device_biscuit`
- Rama: `stock-audio-tuning`
- Usuario: español, conciso; está molesto con ir “a cuentagotas”.
- No commitear logs/capturas crudas, ZIPs, `update.bin`, `system.img`.
- MR: https://gitlab.com/mjfuertesf/amazon_device_biscuit/-/merge_requests/8

## Build/flasheo hecho
- Build Docker terminado OK: contenedor `cm12-biscuit-build` id `22d119600ece`, duración `19:14`.
- OTA flasheada vía TWRP sideload:
  - `workspace/cm12/out-docker/target/product/biscuit/cm_biscuit-ota-f7d1b3d93c.zip`
  - sha256 `431e48e346314220e623b17a93d3875feae60daf5d83fe6dfc573d6a54b489b7`
- `/data` wipe hecho vía TWRP: `twrp wipe data`.

## Boot/Wi‑Fi
- Arranca: `sys.boot_completed=true`.
- `ro.config.no_gpu=true`, `debug.sf.headless=1`.
- Wi‑Fi conectado con `biscuit_service wifi connect`; IP `192.168.77.104/24`, gateway `192.168.77.1`, ping OK.
- No repetir la clave en logs/handoffs.

## Ava
- Ava ya no crashea por HWUI/RenderThread/EGL en la prueba.
- Se instaló por error `../ava5/twrp/build/official-apk/Ava-0.6.2-release.apk`; usuario realmente quería UXPlay.
- Ava/audio/mic no sonaban; logs mostraron ruta audio llegando pero HAL con problemas.

## UXPlay
- APK instalado correcto:
  - `../a2uxplay-v0.0.16-headless-armeabi-v7a-release-debugsigned.apk`
  - sha256 `721d15465fa8aa17d7269e651f8a7597095892793434115384ae0a37a0377244`
  - package `net.mfuertes.airplay.audio`
- Lanzado con `monkey`; proceso vivo inicialmente.
- Durante stream AirPlay:
  - TCP `:7000` llegó a estar `ESTABLISHED`.
  - `AudioFlinger` tenía 1 track activo del cliente UXPlay.
  - No sonaba nada.
- Al reconectar/cortar stream, UXPlay murió:
  - `Fatal signal 11 (SIGSEGV)` en `Thread-236`
  - abort: `Native thread exited without calling DetachCurrentThread`
  - se desregistró NSD/mDNS, por eso dejó de aparecer AirPlay.

## Audio HAL diagnóstico actualizado
- Antes faltaban configs stock y el síntoma era:
  - `AudioALSAPlaybackHandlerNormal: write(), mPcm == NULL, return`
- Copiados live desde `workspace/vendor/.../etc` a `/system/etc` y reiniciado:
  - `audio_device.xml`, `audio_init.sh`, `audio_policy.conf`, `mtk_omx_core.cfg`
- Resultado:
  - OMX ya lee `mtk_omx_core.cfg`.
  - HAL carga `audio_device.xml`.
  - Playback abre `pcmindex = 23`, `mPcm != NULL`, aplica `ext_speaker_output`.
  - Mic/Ava abre `pcmindex = 24`; Ava de sistema queda viva y el micro arranca (`Microphone started, isRecording=true`).
  - Ejecutar `/system/etc/audio_init.sh` aplicó mixers de mic/DAC; después UXPlay sonó.
- `persistentLedState`:
  - `audio_init.sh` intenta crear `/tmp/persistentLedState`.
  - `audio.primary_amazon.mt8163.so` contiene `ledLoop/readLedFile` y monitoriza ese path con `inotify`.
  - En CM12 `/tmp` no existe y `/` es read-only; queda como warning. Usuario decidió documentarlo y no arreglarlo si no falla.

## Corrección hecha después del flasheo actual (no compilada/flasheada aún)
Fuente usada: `workspace/extracted/stock-ota-272.6.4.1/system.img` derivado del OTA/update.bin local, no del dispositivo vivo.

Añadidos a `workspace/vendor/amazon/biscuit/proprietary/etc/` y staged en `workspace/cm12/vendor/...`:
- `audio_device.xml`
- `audio_init.sh`
- `audio_policy.conf`
- `mtk_omx_core.cfg`

Editados:
- `workspace/vendor/amazon/biscuit/biscuit-vendor.mk`
- `workspace/cm12/vendor/amazon/biscuit/biscuit-vendor.mk`
- `workspace/scripts/extract-biscuit-stock-blobs.sh`

No se añadieron `audio-algorithms/*` porque no aparecen en el `system.img` del OTA 272.6.4.1; venían de captura live más nueva y se quitaron para no mezclar fuentes.

## Próximo paso
1. Hacer persistente la ejecución de `/system/etc/audio_init.sh` en boot (init/device), porque copiar el script no lo ejecuta solo.
2. Build Docker detached para incluir configs y el hook de `audio_init.sh`.
3. Flashear nueva OTA vía TWRP sideload.
4. Verificar que UXPlay suena y Ava abre mic tras reboot sin ejecución manual.
5. No implementar `/tmp/persistentLedState` salvo que aparezca fallo real relacionado.

## Skills sugeridos
- `diagnose`
- `context-mode`
- `ponytail` activo: cambios mínimos, pero no más cuentagotas innecesario.
