# Errores no-codec tras OTA reproducible CM12 Biscuit

Fecha de prueba: 2026-07-30  
Build probado: `12.1-20260730-UNOFFICIAL-biscuit` (`01a9cd04df`)  
Resultado base: arranca, `sys.boot_completed=1`, WiFi funcional.

Excluido deliberadamente: MediaCodec/OMX/stagefright/mediaserver/AudioFlinger.

## 1. Trebuchet crashea

```txt
Process: com.cyanogenmod.trebuchet
FATAL EXCEPTION: main
java.lang.RuntimeException: Unable to get provider com.android.launcher3.LauncherProvider
Caused by: java.lang.NullPointerException: IAppWidgetService.deleteHost(...) on null object reference
at android.appwidget.AppWidgetHost.deleteHost(AppWidgetHost.java:283)
at com.android.launcher3.LauncherProvider$DatabaseHelper.onCreate(LauncherProvider.java:515)
```

Acción sugerida: quitar Trebuchet/launcher del build headless en vez de arreglar widgets.

## 2. WiFi con warnings aunque funciona

Red confirmada OK:

```txt
wlan0 UP
IP 192.168.77.104/24
default via 192.168.77.1
ping gateway: 0% loss
ping 8.8.8.8: 0% loss
ping google.com: 0% loss
```

Ruido observado:

```txt
wpa_driver_nl80211_driver_cmd: failed to issue private commands
Unexpected BatchedScanResults :null
```

Acción sugerida: prioridad baja; revisar helper driver_cmd solo si afecta features reales.

## 3. SELinux permissive: denies

```txt
avc: denied { mounton } for pid=161 comm="init" path="/system"
avc: denied { read write } for pid=1173 comm="dhcpcd" path="/dev/pts/0"
avc: denied { module_request } for pid=178 comm="netd" kmod="net-pf-16-proto-5"
```

No bloquea porque está permissive. Deuda futura si se endurece SELinux.

## 4. Servicios init sin dominio SELinux

```txt
Service wmtLoader needs a SELinux domain defined
Service conn_launcher needs a SELinux domain defined
Service dhcpcd_wlan0 needs a SELinux domain defined
```

Acción sugerida: solo arreglar si se mantiene el servicio y se avanza hacia enforcing.

## 5. Apps/servicios CM sobrantes

Ejemplos:

```txt
Unknown permission ...
unavailable shared library ...
no app suggest provider found
no available spell checker services found
RADIO_NOT_AVAILABLE / No UICC
```

Acción sugerida: limpiar apps y servicios no usados en Biscuit headless.

## 6. Kernel/device-tree warnings

```txt
mediatek,mt8163-mfgsys not found
auxadc_apmix_base error
AUXADC_AP find node failed
tsl2540 probe failed
lp5523x detect failed, trying reset
Failed to read shutdown rtc boot reason
Failed to read boot rtc boot reason
/dev/hw_random not found
```

Acción sugerida: revisar solo si afectan sensores, LED o boot reason; no bloquean arranque actual.

## 7. Mount/init noise

```txt
fs_mgr_mount_all returned error 255
Device or resource busy
unknown flag resize
```

`/system`, `/data` y `/cache` quedaron montados correctamente. Prioridad baja salvo boot flakiness.

## Prioridad sugerida para PR no-codec

1. Quitar Trebuchet/launcher.
2. Limpiar apps CM sobrantes de build headless.
3. Dejar WiFi/SELinux/kernel warnings como deuda salvo síntoma real.
