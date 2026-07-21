# PRD — Integración MTK WiFi userspace para Biscuit CM12

## Problem Statement

El WiFi STA de Biscuit en CM12 ya levanta el lado kernel/firmware/WMT: el driver carga, `wlan0` aparece, la MAC es correcta y el estado `wlan.driver.status` llega a `ok`. El problema está en la pila userspace/framework: el framework Android llama features legacy/MTK (`WPS`, `P2P`, `external_sim`, HAL scan MAC OUI, comandos driver privados) y el `wpa_supplicant`/helper actual no forma una pila coherente, causando SIGSEGV o paradas del supplicant.

El usuario prefiere dejar de parchear síntomas uno a uno si existe una pila MediaTek userspace más completa y compatible con el hardware MT8163/CONSYS. El repo MTK de referencia parece contener precisamente esa pila: helper privado `lib_driver_cmd_mt66xx`, WiFi HAL MTK y configuración de `wpa_supplicant` con P2P/WPS/AP/HS20.

## Solution

Vendorizar e integrar la pila WiFi userspace MTK de forma controlada, preservando lo Amazon/Biscuit que ya funciona. La integración debe avanzar por capas: primero helper privado, luego flags/config del supplicant, luego HAL MTK si el framework lo requiere. El objetivo es obtener una pila más coherente para MTK sin pisar firmware, WMT launcher, init scripts ni blobs/configs que ya hacen arrancar el radio.

La solución no debe ser un copy-paste wholesale sin diagnóstico. Debe usar el repo MTK como base compatible con el hardware, pero aplicar modificaciones quirúrgicas Biscuit para evitar regresiones conocidas: crash temprano de `DRIVER MACADDR`, conflictos de símbolos CM12, rutas de build, firmware Amazon y features fuera de alcance.

## User Stories

1. As a Biscuit bring-up developer, I want WiFi STA to start from Android framework, so that `svc wifi enable` leaves `wpa_supplicant` running.
2. As a Biscuit bring-up developer, I want `wpa_cli ping` to return `PONG`, so that the supplicant control path is healthy.
3. As a Biscuit bring-up developer, I want `DRIVER MACADDR` to return the device MAC without crashing, so that CM12 can initialize `WifiInfo` safely.
4. As a Biscuit bring-up developer, I want `wlan0` to keep using the working Amazon/WMT firmware path, so that we do not regress radio bring-up.
5. As a Biscuit bring-up developer, I want MTK private driver commands available, so that framework commands like country, start/stop, statistics, and coexistence have real handlers.
6. As a Biscuit bring-up developer, I want WPS/P2P/AP flags restored only when build/runtime proves they are needed, so that STA bring-up remains debuggable.
7. As a Biscuit bring-up developer, I want the MTK WiFi HAL available if the CM12 stub blocks scans or framework init, so that HAL calls do not force framework fallback/crash paths.
8. As a Biscuit bring-up developer, I want each integration layer to be flashable and testable independently, so that failures identify the responsible layer.
9. As a Biscuit bring-up developer, I want firmware/config ownership to stay explicit, so that generic MTK firmware does not overwrite known-good Biscuit firmware.
10. As a Biscuit bring-up developer, I want rollback to the last known OTA, so that failed WiFi experiments do not strand the device.
11. As a Biscuit bring-up developer, I want no stock fastboot or ADB `dd` flashing, so that partition safety rules remain intact.
12. As a Biscuit bring-up developer, I want builds to run detached in Docker, so that long CM12 builds do not block interactive diagnosis.
13. As a Biscuit bring-up developer, I want no PSKs printed in logs or docs, so that test WiFi credentials remain secret.
14. As a Biscuit bring-up developer, I want scan results before association attempts, so that RF and supplicant scan paths are proven before credentials are used.
15. As a Biscuit bring-up developer, I want a path to full MTK userspace WiFi if STA-only keeps exposing missing features, so that we stop chasing one framework command at a time.

## Implementation Decisions

- Preserve working hardware bring-up pieces: firmware blobs, WMT launcher flow, init properties, permissions, and `wlan0` setup that already produce `wlan.driver.status=ok`.
- Vendorize only WiFi userspace-relevant MTK components first: private supplicant helper, WiFi HAL, and configs for comparison.
- Do not initially copy MTK firmware, combo tools, Bluetooth, GPS, audio, or unrelated hardware modules.
- Integrate `lib_driver_cmd_mt66xx` first. It is the deepest useful module: framework/supplicant issue simple `DRIVER` commands, while the helper encapsulates MTK ioctl/private command behavior.
- Patch `DRIVER MACADDR` defensively for Biscuit. If supplicant state is not ready, read `/sys/class/net/wlan0/address` rather than dereferencing supplicant/driver pointers.
- Treat MTK `wpa_supplicant` flags as a coherent target, but restore them incrementally. First candidates are WPS, P2P and AP; HS20, Interworking and WiFi Display come later only if required.
- Integrate `libwifi-hal-mt66xx` only after helper/supplicant stability, or earlier if framework HAL failure blocks scans/init.
- Keep HAL failure non-fatal for STA where possible; HAL scan randomization and advanced features are not required for basic STA association.
- Resolve duplicate symbols by choosing either CM12 native implementation or MTK helper implementation per function, not both.
- Keep changes small and bisectable: one integration layer per OTA when practical.
- Use the MTK repo as hardware-compatible source, not as an unquestioned replacement for Amazon/Biscuit board behavior.

## Testing Decisions

- Tests should verify external behavior on the device, not implementation details.
- Minimum hardware checks per phase:
  - boot completes and ADB returns as `device`;
  - `svc wifi enable` sets `wlan.driver.status=ok`;
  - `init.svc.wpa_supplicant` remains `running`;
  - `wpa_cli -p/data/misc/wifi/sockets -iwlan0 ping` returns `PONG`;
  - `wpa_cli ... DRIVER MACADDR` returns the Biscuit MAC without crashing;
  - `wpa_cli ... scan` succeeds;
  - `wpa_cli ... scan_results` returns visible networks.
- Only after scan works should saved network credentials be tested.
- Build validation for each OTA:
  - Docker detached build exits successfully;
  - newest OTA is located deterministically;
  - `unzip -t` reports no errors;
  - `sha256sum` is recorded.
- Flash validation:
  - confirm TWRP over ADB with `/sbin/twrp` and `ro.twrp.version`;
  - push/install ZIP through TWRP;
  - avoid `adb wait-for-device` as a progress signal;
  - never write partitions with `dd` from Android/ADB.

## Out of Scope

- Bluetooth bring-up.
- Audio/speaker runtime tests.
- WiFi Display validation.
- AP/tethering validation beyond build/runtime compatibility needed for STA.
- P2P feature validation unless required to stabilize framework initialization.
- Replacing Amazon firmware/WMT flow with generic MTK firmware or combo tools.
- Stock fastboot flashing, GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc changes.

## Further Notes

The user believes, reasonably, that a MediaTek userspace WiFi stack matching the hardware may be better than repeated one-off framework bypasses. The integration strategy should respect that direction while keeping enough layering to diagnose failures.

The current known-good base before MTK integration is: kernel/WMT/firmware load works, `wlan0` exists with MAC `fc:65:de:85:6f:a5`, and manual/init-started `wpa_supplicant` can respond to `PONG` in some configurations. The failing area is framework-driven initialization of the supplicant and optional/advanced WiFi features.
