# CM12 para Amazon Biscuit (Echo Dot 2nd gen)

Port de CyanogenMod 12 para el Amazon Fire HD 6 (Biscuit) usando el source release de Amazon
Echo Dot 5.5.5.4 como fuente de verdad.

> **No se flashea nada todavía.** Los scripts de build producen imágenes; el flasheo
> es un paso manual explícito documentado en `docs/amonet-biscuit-unlock.md`.

---

## Estructura del workspace

```
workspace/
├── downloads/    # Archivos descargados (ignorados por git): ZIPs, checksums, temporales
├── kernel/       # Source kernel Amazon trackeado (kernel/amazon/biscuit)
├── cm12/         # Árbol CM12: repo sync destino + patches aplicados
├── docker/       # Dockerfile y contexto del contenedor de build (Ubuntu 14)
├── scripts/      # build.sh y utilidades reproducibles
├── patches/      # Parches explícitos sobre copias de trabajo (no sobre upstream)
├── device/       # Device tree CM12 para biscuit (device/amazon/biscuit)
└── vendor/       # Blobs propietarios (ignorados por git)
```

`workspace/tools/` — herramientas de unlock (amonet, ignoradas por git).

---

## Reproducir en otro ordenador

Inputs ignorados por git que debes aportar:

- Biscuit OTA stock extraída hasta `workspace/extracted/biscuit-ota/system.img`
- checkout CM12 en `workspace/cm12/`
- imágenes Docker `biscuit-kernel-builder:latest` y `cm12-ubuntu14:latest`

Orden mínimo:

```sh
workspace/scripts/extract-biscuit-stock-blobs.sh workspace/extracted/biscuit-ota/system.img
workspace/scripts/build-kernel.sh
workspace/scripts/build.sh
```

El kernel sale de `workspace/kernel/amazon/biscuit` usando `biscuit_defconfig`.
La URL/checksum del tar original quedan documentados en `workspace/kernel/amazon/biscuit/README.md`.
El sistema usa blobs stock Biscuit no-GPU/headless; el extractor excluye blobs Mali no usados.

## CI GitLab on-demand

La pipeline solo se crea manualmente desde **Run pipeline** (`workflow: web`). Requiere runner Docker privilegiado.

Variables necesarias:

- `BISCUIT_SYSTEM_IMG_URL`: URL descargable a `system.img` stock Biscuit ya convertido a ext4.
- `CM12_TARBALL_URL`: tar de un checkout CM12 preparado; por defecto se extrae con `--strip-components=1`.
- `CM12_STRIP_COMPONENTS`: opcional, cambia el strip del tar CM12.

Artefactos CI: OTA zip, `boot.img`, `system.img`, kernel-selection y logs Docker.

## Flujo build

### 1. Build (`workspace/scripts/build.sh`)

Levanta el contenedor Docker estable (`cm12-biscuit-build`) y ejecuta:

```sh
source build/envsetup.sh
lunch cm_biscuit-userdebug
make -j$(nproc) otapackage
```

El output va a `workspace/cm12/out-docker/` (ruta absoluta, ignorada por git).
El contenedor **no** se elimina al terminar para preservar logs.

### 3. Flasheo (manual, fase futura)

Ver `docs/amonet-biscuit-unlock.md`. Se flashea desde TWRP o hacked fastboot — nunca
con `dd` desde Android ni con stock fastboot.

---

## Reglas de seguridad del dispositivo

- No `adb shell dd of=/dev/block/...` bajo ningún concepto.
- No stock fastboot para ROMs.
- No tocar GPT/preloader/LK/TZ/recovery/userdata salvo petición explícita.
- Para entrar en TWRP o hacked fastboot, ver `AGENTS.md`.
