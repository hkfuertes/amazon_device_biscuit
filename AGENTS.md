# AGENTS.md

Reglas para agentes en este repo.

## Referencias

- Ayuda Amazon: https://www.amazon.com/gp/help/customer/display.html?nodeId=201626480
- Notas amonet Biscuit: `docs/amonet-biscuit-unlock.md`
- amonet local ignorado por git: `workspace/tools/amonet-biscuit-v1.1.0/amonet`
- amonet root-owned con sudo NOPASSWD solo para boot: `/opt/amonet-biscuit-v1.1.0/amonet`

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

El build local nativo falla por Python 2 legacy. Usa Docker:

```sh
docker run --rm -v "$PWD:$PWD" -w "$PWD/workspace/cm12" cm12-ubuntu14:latest \
  bash -lc 'source build/envsetup.sh >/dev/null && lunch cm_biscuit-userdebug >/tmp/lunch.log && export OUT_DIR="$PWD/out-docker" && export PATH="$OUT_DIR/host/linux-x86/bin:$PATH" && make -j$(nproc) otapackage'
```

Notas:

- `OUT_DIR` debe ser absoluto (`$PWD/out-docker` dentro de `workspace/cm12`); `OUT_DIR=out-docker` rompe recovery por rutas relativas.
- Si cambian flags de `hostapd`, limpia sus intermediates desde Docker porque `out-docker` queda owned by root.

## Flasheo recomendado

Preferir ZIP desde TWRP:

```sh
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
