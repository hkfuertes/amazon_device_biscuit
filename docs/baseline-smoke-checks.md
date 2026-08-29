# Baseline smoke checks — CM12 Biscuit

Accepted state for this ROM: `userdebug`, permissive SELinux, and root/ADB root
can be enabled. Do not treat those as failures.

## Baseline OK

After flashing an OTA, the baseline is valid if:

```sh
adb devices -l
adb shell 'getprop ro.build.fingerprint; getprop ro.cm.version; getprop ro.product.device; getprop ro.boot.slot_suffix; getprop sys.boot_completed; uptime'
adb shell 'mount | grep -E " /system | /data | /cache "; df /system /data /cache'
adb shell 'ps | grep -E "(zygote|system_server|surfaceflinger|mediaserver|netd|wpa_supplicant|biscuit|adbd)"'
adb shell 'getprop | grep -E "\[(init\.svc\.(media|zygote|surfaceflinger|netd|wpa_supplicant|biscuit)|sys\.boot_completed|wlan\.|dhcp\.|wifi\.)"'
```

Expected:

- ADB returns as `device`.
- `sys.boot_completed=1`.
- `ro.product.device=biscuit`.
- Actual ROM slot: `_a` or `_b`, depending on the build/flash.
- `/system` is mounted `ro`; `/data` and `/cache` are mounted `rw`.
- Live processes: `zygote`, `system_server`, `surfaceflinger`, `netd`, `wpa_supplicant`, `biscuit-ledd`, `com.amazon.biscuit.service`.
- Wi-Fi has `wlan.driver.status=ok`, DHCP `ok`, and an address on `wlan0`.

## Network checks

```sh
adb shell 'ip addr show wlan0; ip route'
adb shell 'ping -c 2 -W 2 192.168.77.1; ping -c 2 -W 2 8.8.8.8; ping -c 2 -W 2 google.com'
```

Expected:

- `wlan0` is `UP,LOWER_UP`.
- The default route goes through the local gateway.
- Gateway/internet/DNS pings have `0% packet loss`.

## Known failures that do NOT invalidate the baseline

### Trebuchet/headless UI

```txt
Process: com.cyanogenmod.trebuchet
FATAL EXCEPTION: main
LauncherProvider / AppWidgetHost.deleteHost / IAppWidgetService null
```

Track as headless cleanup; remove Trebuchet/the launcher instead of fixing
widgets.

### Wi-Fi warnings with a working network

```txt
wpa_driver_nl80211_driver_cmd: failed to issue private commands
Unexpected BatchedScanResults :null
```

These do not invalidate the baseline if DHCP and ping work.

### Permissive SELinux/root/userdebug

```txt
avc: denied ... permissive=1
Service ... needs a SELinux domain defined
```

Accepted for this ROM. Fix only if it blocks something real.

### CM noise/unneeded apps

```txt
Unknown permission ...
unavailable shared library ...
RADIO_NOT_AVAILABLE / No UICC
no app suggest provider found
no available spell checker services found
```

Track as headless cleanup.

### Non-blocking kernel/device-tree warnings

```txt
mt8163-mfgsys not found
auxadc_apmix_base error
tsl2540 probe failed
lp5523x detect failed
Failed to read rtc boot reason
/dev/hw_random not found
```

These do not invalidate the baseline unless there is a sensor/LED/boot-reason
symptom.

## Real failure criteria

Start an investigation if any of the following occurs:

- ADB does not return after a reasonable/manual boot period.
- `sys.boot_completed` does not reach `1`.
- Boot loop or spontaneous reboot.
- `system_server`/`zygote` is dead or restarting.
- `/data` or `/cache` is not mounted `rw`.
- Wi-Fi has no IP/DHCP or cannot ping the gateway.
- `biscuit-ledd` does not start.
- A new kernel panic/oops.
