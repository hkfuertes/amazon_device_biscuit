# Baseline smoke checks — CM12 Biscuit

Estado aceptado para esta ROM: `userdebug`, SELinux `permissive`, root/ADB root habilitable. No tratar eso como fallo.

## Baseline OK

Tras flashear una OTA, la base se considera válida si:

```sh
adb devices -l
adb shell 'getprop ro.build.fingerprint; getprop ro.cm.version; getprop ro.product.device; getprop ro.boot.slot_suffix; getprop sys.boot_completed; uptime'
adb shell 'mount | grep -E " /system | /data | /cache "; df /system /data /cache'
adb shell 'ps | grep -E "(zygote|system_server|surfaceflinger|mediaserver|netd|wpa_supplicant|biscuit|adbd)"'
adb shell 'getprop | grep -E "\[(init\.svc\.(media|zygote|surfaceflinger|netd|wpa_supplicant|biscuit)|sys\.boot_completed|wlan\.|dhcp\.|wifi\.)"'
```

Esperado:

- ADB vuelve como `device`.
- `sys.boot_completed=1`.
- `ro.product.device=biscuit`.
- slot real ROM: `_a` o `_b` según build/flasheo.
- `/system` montado `ro`; `/data` y `/cache` montados `rw`.
- procesos vivos: `zygote`, `system_server`, `surfaceflinger`, `netd`, `wpa_supplicant`, `biscuit-ledd`, `com.amazon.biscuit.service`.
- WiFi con `wlan.driver.status=ok`, DHCP `ok`, IP en `wlan0`.

## Checks red

```sh
adb shell 'ip addr show wlan0; ip route'
adb shell 'ping -c 2 -W 2 192.168.77.1; ping -c 2 -W 2 8.8.8.8; ping -c 2 -W 2 google.com'
```

Esperado:

- `wlan0` `UP,LOWER_UP`.
- ruta default vía gateway local.
- ping gateway/internet/DNS con `0% packet loss`.

## Fallos conocidos que NO invalidan baseline

### Trebuchet/headless UI

```txt
Process: com.cyanogenmod.trebuchet
FATAL EXCEPTION: main
LauncherProvider / AppWidgetHost.deleteHost / IAppWidgetService null
```

Track: cleanup headless; quitar Trebuchet/launcher en vez de arreglar widgets.

### WiFi warnings con red funcional

```txt
wpa_driver_nl80211_driver_cmd: failed to issue private commands
Unexpected BatchedScanResults :null
```

No invalida baseline si DHCP y ping funcionan.

### SELinux permissive/root/userdebug

```txt
avc: denied ... permissive=1
Service ... needs a SELinux domain defined
```

Aceptado para esta ROM. Solo arreglar si bloquea algo real.

### Ruido CM/apps sobrantes

```txt
Unknown permission ...
unavailable shared library ...
RADIO_NOT_AVAILABLE / No UICC
no app suggest provider found
no available spell checker services found
```

Track: cleanup headless.

### Kernel/device-tree warnings no bloqueantes

```txt
mt8163-mfgsys not found
auxadc_apmix_base error
tsl2540 probe failed
lp5523x detect failed
Failed to read rtc boot reason
/dev/hw_random not found
```

No invalida baseline salvo síntoma en sensor/LED/boot reason.

## Criterio de fallo real

Abrir investigación si aparece cualquiera de estos:

- ADB no vuelve tras arranque razonable/manual.
- `sys.boot_completed` no llega a `1`.
- bootloop/reinicio espontáneo.
- `system_server`/`zygote` muertos o reiniciando.
- `/data` o `/cache` no montan `rw`.
- WiFi sin IP/DHCP o sin ping a gateway.
- `biscuit-ledd` no arranca.
- kernel panic/oops nuevo.
