# CM12 para Amazon Biscuit (Echo Dot 2nd gen)

Port de CyanogenMod 12 para el Amazon Fire HD 6 (Biscuit) usando el source release de Amazon
Echo Dot 5.5.5.4 como fuente de verdad.

> **No se flashea nada todavía.** Los scripts de build producen imágenes; el flasheo
> es un paso manual explícito documentado en `docs/amonet-biscuit-unlock.md`.

---

## Estructura del workspace

```
workspace/
├── downloads/    # Archivos descargados (ignorados por git): tarballs, ZIPs, checksums
├── upstream/     # Extracción intacta del source Amazon — no modificar nunca (ignorado)
├── cm12/         # Árbol CM12: repo sync destino + patches aplicados
├── docker/       # Dockerfile y contexto del contenedor de build (Ubuntu 14)
├── scripts/      # preflight.sh, build.sh y utilidades reproducibles
├── patches/      # Parches explícitos sobre copias de trabajo (no sobre upstream)
├── device/       # Device tree CM12 para biscuit (device/amazon/biscuit)
└── vendor/       # Blobs propietarios (ignorados por git)
```

`workspace/tools/` — herramientas de unlock (amonet, ignoradas por git).

---

## Flujo preflight → build

### 1. Preflight (`workspace/scripts/preflight.sh`)

*No compila nada.* Responsable de:

1. Descargar el source release de Amazon (checksum verificado) → `workspace/downloads/`
2. Extraer en `workspace/upstream/` sin modificar nada
3. Generar symlinks/copias hacia `workspace/cm12/` y `workspace/vendor/` según necesite el build de Android

### 2. Build (`workspace/scripts/build.sh`)

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
