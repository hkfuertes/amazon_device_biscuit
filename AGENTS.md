# AGENTS.md

Reglas para agentes en este repo.

## Referencias

- Ayuda Amazon: https://www.amazon.com/gp/help/customer/display.html?nodeId=201626480
- Source Amazon Echo Dot 5.5.5.4: https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/Echo_Dot_src-5.5.5.4-20220824.tar.bz2
- Amazon OSS MT8163 common: https://github.com/amazon-oss/android_device_amazon_mt8163-common
- Amazon OSS hardware helpers: https://github.com/amazon-oss/android_hardware_amazon/tree/cm-12.1
- Vendor Amazon MT8163 common CM14.1: https://github.com/mt8163-dev/android_vendor_amazon_mt8163-common/tree/cm-14.1/
  - Útil para comparar blobs/configs audio MTK/Amazon: `audio.primary.mt8163.so`, `libaudio*`, `libbessound_hd_mtk.so`, `vendor/etc/audio-algorithms/*`, `vendor/lib/soundfx/libswdap.so`.
- Rook LineageOS aprobado/referencia audio:
  - Device: https://github.com/amazon-oss/android_device_amazon_rook
  - Vendor: https://github.com/amazon-oss/android_vendor_amazon_rook
  - Hardware wrapper: https://github.com/amazon-oss/android_hardware_amazon/tree/lineage-18.1/audio/hal
  - Patrón útil: compilar `audio.primary.amazon_wrapper` y cargar blob vendor `audio.primary_amazon.mt8163.so` con deps/tuning en `/vendor`.
- MTK hardware helper referencia: https://github.com/lbule/android_hardware_mediatek
  - Usar solo para comparar/extraer ideas puntuales de `wlan/wpa_supplicant_8_lib/mediatek_driver_cmd_nl80211.c` (`lib_driver_cmd_mt66xx`): `COUNTRY`, `GET_STA_STATISTICS`, start/stop/AP si hace falta.
  - No sustituir wholesale nuestro helper Amazon/CM12: su `DRIVER MACADDR` también dereferencia `priv` antes de responder y no arregla el SIGSEGV as-is.
- OTA Biscuit full 272.6.4.1: https://d1s31zyz7dcc2d.cloudfront.net/8811a0fc982bf3331dc54f5aec45d936/update-kindle-full_biscuit-272.6.4.1_user_641575220.bin
- Notas amonet Biscuit: `docs/amonet-biscuit-unlock.md`
- amonet local ignorado por git: `workspace/tools/amonet-biscuit-v1.1.0/amonet`
- amonet root-owned con sudo NOPASSWD solo para boot: `/opt/amonet-biscuit-v1.1.0/amonet`

## Workflow del agente

- Antes de cada acción operativa, decir explícitamente qué voy a hacer, qué no voy a hacer y por qué.
- En este dispositivo `adb wait-for-device` puede quedarse colgado o no ser buena señal de progreso. Preferir chequeos explícitos con `adb devices -l`, estado visual del LED/TWRP, y timeouts cortos; si ADB no aparece, parar y reportar.
- Salvo petición explícita del usuario, no hacer polling ni esperas largas. Los builds/flash/reboots largos deben lanzarse detached o como una acción concreta, reportar cómo mirarlos, y devolver control para que el usuario pueda preguntar entre pasos.
- Cualquier cambio dentro de `workspace/cm12` debe tener una forma reproducible desde el repo trackeado: preferir `workspace/patches/*.patch`, `workspace/scripts/stage-tree.sh`, `workspace/scripts/apply-patches.sh` o scripts equivalentes. No dejar cambios manuales solo en `workspace/cm12`.

## Seguridad del dispositivo

- Nunca escribas particiones con `dd` desde Android/ADB. Nada de:
  - `adb shell dd of=/dev/block/...`
  - `adb exec-in dd of=/dev/block/...`
- Para flashear boot/system usa solo TWRP o hacked fastboot de amonet.
- No uses stock fastboot para ROMs: puede estar restringido y no remapea particiones amonet.
- No tocar GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc salvo petición explícita.
- En amonet, los boot reales de ROM son `boot_a_x` / `boot_b_x`; `boot_a` / `boot_b` contienen el exploit. TWRP/hacked fastboot hacen el remapeo.
- El usuario concedió sudo NOPASSWD solo para `/opt/amonet-biscuit-v1.1.0/amonet/boot-recovery.sh` y `boot-fastboot.sh`. No asumir permisos para `brick.sh`, `bootrom-step.sh`, `fastboot-step.sh` ni `gpt-fix.sh`.
- Ejecutar scripts amonet con stdin cerrado y log redirigido para no romper tmux: `sudo -n ./boot-recovery.sh </dev/null >/tmp/amonet-boot-recovery.log 2>&1`.
- Si un kernel no arranca y entra en bootloop, el “desenchufar y enchufar” de los métodos manuales puede resolverse esperando el siguiente ciclo de arranque.

## Entrar en TWRP

TWRP se indica con LED cyan parpadeante/pulsante.

Métodos:

1. Desde apagado/desenchufado: enchufar y, al aparecer LED azul, mantener botón mute/micrófono unos 5s.
2. Desde Linux con amonet:
   ```sh
   cd /opt/amonet-biscuit-v1.1.0/amonet
   sudo -n ./boot-recovery.sh </dev/null >/tmp/amonet-boot-recovery.log 2>&1
   ```
   Luego enchufar el dispositivo.
3. Desde hacked fastboot:
   ```sh
   fastboot oem reboot-recovery
   ```
4. Desde un OS con ADB funcional:
   ```sh
   adb reboot recovery
   ```

## Entrar en hacked fastboot

Hacked fastboot se indica con aro rainbow girando.

Métodos:

1. Desde apagado/desenchufado: enchufar y, ~3s después del LED azul, mantener botón action/círculo unos 5s.
2. Desde TWRP:
   ```sh
   adb shell reboot-amonet
   ```
   Importante: `adb reboot` no sirve para esto.
3. Desde Linux con amonet:
   ```sh
   cd /opt/amonet-biscuit-v1.1.0/amonet
   sudo -n ./boot-fastboot.sh </dev/null >/tmp/amonet-boot-fastboot.log 2>&1
   ```
   Luego enchufar el dispositivo.

## Build CM12

El build local nativo falla por Python 2 legacy. Usa Docker.

Para compilar/generar OTA en background, usar siempre Docker detached para que el usuario pueda seguir escribiendo y monitorizar:

```sh
docker rm -f cm12-biscuit-build >/dev/null 2>&1 || true
docker run -d --name cm12-biscuit-build \
  -v "$PWD:$PWD" \
  -w "$PWD/workspace/cm12" \
  cm12-ubuntu14:latest \
  bash -lc 'source build/envsetup.sh >/dev/null && lunch cm_biscuit-userdebug && export OUT_DIR="$PWD/out-docker" && export PATH="$OUT_DIR/host/linux-x86/bin:$PATH" && make -j$(nproc) otapackage'
```

Notas:

- `OUT_DIR` debe ser absoluto (`$PWD/out-docker` dentro de `workspace/cm12`); `OUT_DIR=out-docker` rompe recovery por rutas relativas.
- Si cambian flags de `hostapd`, limpia sus intermediates desde Docker porque `out-docker` queda owned by root.
- Para cualquier build/OTA/compilación larga, no usar foreground: contenedor fijo `cm12-biscuit-build` con `docker run -d`.

## Repos relacionados

- `../cm12-biscuit` es solo para leer/aprender. No ensuciarlo.
- No copiar nada as-is desde `../cm12-biscuit` sin pedir permiso explícito al usuario.

## Flasheo recomendado

Preferir ZIP desde TWRP. Confirmar primero que ADB ve `recovery` y que existe `/sbin/twrp`; no depender solo de `adb wait-for-device`.

```sh
adb devices -l
adb shell 'command -v twrp; getprop ro.twrp.version'
adb push update.zip /sdcard/
adb shell twrp install /sdcard/update.zip
```

O hacked fastboot confirmado:

```sh
fastboot getvar all
fastboot flash boot boot.img
fastboot flash system system.img
```

Solo si `getvar all` confirma amonet/hacked fastboot. Si parece stock/restringido, parar.
