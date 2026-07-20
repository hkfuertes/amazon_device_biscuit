# CM12 Biscuit bring-up decisions

Registro breve de decisiones tomadas durante el bring-up de CM12. Mantener esto actualizado cuando cambiemos estrategia.

## Seguridad / flasheo

- No usar `dd` desde Android/ADB para escribir particiones.
  - Motivo: reduce riesgo de brick; usar TWRP o hacked fastboot de amonet.
- Flashear boot/system solo vía ZIP en TWRP o hacked fastboot confirmado.
  - Motivo: stock fastboot puede estar restringido y amonet remapea particiones.
- No tocar GPT/preloader/LK/TZ/recovery/userdata/cache/persist/misc salvo petición explícita.
  - Motivo: mantener dispositivo recuperable.

## Boot / particiones

- Usar `boot_a_x` / `boot_b_x` como boot reales de ROM; no `boot_a` / `boot_b`.
  - Motivo: en amonet, `boot_a` / `boot_b` contienen el exploit.
- Verificar boot flasheado con lectura `head -c`, no `dd`.
  - Motivo: comprobación segura sin escribir.

## Rootdir / init

- Portar rootdir mínimo al ramdisk: `fstab.mt8163`, `init.device.rc`, `init.mt8163.rc`, `init.mt8163.usb.rc`.
  - Motivo: montar `/system`, `/data`, `/cache` y tener ADB temprano.
- Forzar ADB en `init.mt8163.usb.rc` con `persist.sys.usb.config adb` y `sys.usb.config adb`.
  - Motivo: dispositivo sin pantalla; ADB es el feedback loop principal.
- Crear symlinks mínimos de bloques A/B en init.
  - Motivo: compatibilidad con layout Biscuit/amonet.

## Producto Android

- Cambiar de `embedded.mk` a `core_minimal.mk` + `core_64_bit.mk`.
  - Motivo: `embedded.mk` era demasiado pequeño; faltaban `app_process64`, framework jars y classpaths para `zygote/system_server`.
- Mantener `USE_OPENGL_RENDERER := true`.
  - Motivo: aunque sea headless, `libandroid_runtime` referencia símbolos HWUI; necesita `libhwui` para link/runtime.
- Ajustar AAPT a `normal mdpi` / `mdpi`.
  - Motivo: producto mínimo sin pantalla real, pero framework necesita recursos consistentes.
- Reemplazar `webview` por `nullwebview`.
  - Motivo: Android framework espera un WebView en boot jars, pero Chromium/WebKit no hace falta para bring-up headless y tarda horas en compilar.
  - Implementación: `PRODUCT_PACKAGES := $(filter-out webview,$(PRODUCT_PACKAGES))`, añadir `nullwebview`, y cambiar `PRODUCT_BOOT_JARS` igual.
  - Estado: aplicado en `workspace/device/amazon/biscuit/cm_biscuit.mk` y sincronizado a `workspace/cm12/device/amazon/biscuit/cm_biscuit.mk`.

## Build

- Construir CM12 con Docker `cm12-ubuntu14:latest`.
  - Motivo: build nativo falla por tooling Python 2 legacy.
- `OUT_DIR` debe ser absoluto: `$PWD/out-docker` dentro de `workspace/cm12`.
  - Motivo: `OUT_DIR` relativo rompe rutas de recovery.
- Usar siempre nombre fijo de contenedor: `cm12-biscuit-build`.
  - Motivo: permitir `docker logs -f cm12-biscuit-build` durante builds.
  - Nota: si usamos `--rm`, al terminar desaparece el contenedor; mantener log de archivo en `/tmp/cm12-biscuit-build-*.log`.
- Limpiar intermediates puntuales antes de rebuild si aparecen stale objects.
  - Motivo: evitar limpiezas enormes; ejemplo: limpiar `vold`/`libvold` resolvió el link stale de `Exfat::*`.

## No copias externas

- Se puede consultar `../cm12-biscuit`, pero no copiar sin aprobación explícita.
  - Motivo: usarlo como referencia, no mezclar cambios no revisados.
