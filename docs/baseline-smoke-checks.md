# Baseline smoke checks — CM12.1 Biscuit

> [!WARNING]
> These checks apply only after installing a CM12.1 image through confirmed **Amonet Biscuit v1.1.0** TWRP or v1 hacked fastboot. CM12.1 is the Android 5 / Fire OS 5 line and uses the v1 `boot_a_x` / `boot_b_x` mapping. Do not use this checklist for Amonet 2 or CM14.1.

Use the checklist matching the image actually installed. A data wipe intentionally removes saved Wi-Fi networks, so lack of association immediately after a clean wipe is not a failure.

## Common checks

```sh
adb devices -l
adb shell 'getprop ro.product.name; getprop ro.product.model; getprop sys.boot_completed'
adb shell 'mount | grep " /system "'
```

Baseline expectations:

- ADB sees one `device` entry, not `recovery` or `unauthorized`.
- `/system` is mounted and `sys.boot_completed=1`.
- Never print Wi-Fi credentials in commands, logs, or reports.
- Do not run sound-emitting tests unless they are explicitly authorized.

## Full product

Applies to `cm_biscuit-userdebug` built with `make full`.

```sh
adb shell 'getprop ro.product.name; getprop ro.product.model; getprop sys.boot_completed'
adb shell 'ps | grep -E "zygote|system_server|surfaceflinger|mediaserver|wpa_supplicant|biscuit-ledd"'
adb shell 'command -v biscuit_service; biscuit_service volume up; biscuit_service volume down'
```

Expected baseline:

- Full Android framework services are alive: `zygote`, `system_server`, `surfaceflinger`, and `mediaserver`.
- `biscuit-ledd` and `/system/bin/biscuit_service` are present.
- The device can use the Android Wi-Fi path. After a Data wipe, configure or reconnect a network before requiring DHCP, a route, or ping.
- The full product is allowed to contain APKs and `/system/framework` entries.

## Framework-free minimal product

Applies to `biscuit_minimal-userdebug` built with `make minimal`.

```sh
adb shell 'getprop ro.product.name; getprop ro.product.model; getprop sys.boot_completed'
adb shell 'getprop init.svc.ledcontroller; getprop init.svc.wmtLoader; getprop init.svc.conn_launcher; getprop init.svc.wpa_supplicant'
adb shell 'command -v wpa_connect; command -v wpa_cli; command -v wpa_passphrase; command -v dhcpcd'
adb shell 'find /system -name "*.apk" -o -path "/system/framework/*"'
```

Expected baseline:

- `ro.product.name=biscuit_minimal` and the model is `Echo Dot Minimal Base`.
- `ledcontroller`, `wmtLoader`, `conn_launcher`, and `wpa_supplicant` are managed by init. `dhcpcd_wlan0` starts after a successful association.
- `wpa_connect`, `wpa_cli`, `wpa_passphrase`, and `dhcpcd` are available for root-ADB provisioning.
- The image contains no APKs and no `/system/framework` entries.
- `zygote`, `system_server`, `surfaceflinger`, `mediaserver`, `BiscuitService`, and `biscuit_service` are intentionally absent. Their absence is not a failure.

### Wi-Fi after a wipe

A clean Data wipe has no saved network. This is expected:

```sh
adb shell 'wpa_cli -iwlan0 -p/data/misc/wifi/sockets list_networks'
```

Provision using the root-ADB helper without exposing the credential in logs or reports:

```sh
adb shell wpa_connect '<ssid>' '<psk-or-passphrase>'
adb shell wpa_connect status
```

A successful connection reports `wpa_state=COMPLETED` and an IPv4 address. Then verify the route and a known IP address as appropriate for the local network.

## Non-blocking observations

These do not invalidate the matching baseline by themselves:

- Headless/UI warnings on a device without a display, when the required product services remain alive.
- Supplicant private-command or batched-scan warnings when association, DHCP, and traffic work.
- Permissive SELinux and root ADB in these userdebug bring-up images.

## Real failure criteria

Treat these as failures for the installed product:

- No Android ADB endpoint after a bounded, explicit check.
- `/system` cannot mount or `sys.boot_completed` stays unset.
- The minimal image contains an APK or a `/system/framework` entry.
- The full image cannot keep its core framework services alive.
- A saved/provisioned Wi-Fi network cannot associate, obtain DHCP, or route traffic when the local network is known to be available.
- The CM12.1 image was installed through an Amonet 2 procedure, or a CM14.1 image through an Amonet v1 procedure; stop rather than diagnose across incompatible contracts.
