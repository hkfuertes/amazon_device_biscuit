# Baseline smoke checks — Biscuit CM14.1

This repository builds two different products. Choose the matching checklist;
full-Android expectations do not apply to the framework-free minimal image.

Accepted state for both products: `userdebug`, permissive SELinux, and root ADB
are intentional. Do not treat them as failures by themselves.

## Common boot checks

```sh
adb devices -l
adb shell 'getprop ro.product.name; getprop ro.product.model; getprop ro.product.device; getprop ro.serialno; getprop sys.boot_completed; uptime'
adb shell 'mount | grep -E " /system | /data | /cache "; df /system /data /cache'
```

Expected for either product:

- ADB returns as `device`.
- `ro.product.device=biscuit` and `sys.boot_completed=1`.
- The real IDME serial is exposed through `ro.serialno`.
- `/system` is mounted `ro`; `/data` and `/cache` are mounted `rw`.
- The system partition is the active Amonet 2 slot. `ro.boot.slot_suffix` is
  informative only: CM14 can derive the slot from the Amonet 2 BCB fallback.

## Full product

Scope: `cm_biscuit-userdebug` built with `make full`.

```sh
adb shell 'ps | grep -E "(zygote|system_server|surfaceflinger|audioserver|netd|wpa_supplicant|biscuit-ledd)"'
adb shell 'command -v biscuit_service; getprop init.svc.biscuit-ledd; getprop init.svc.wpa_supplicant'
```

Expected after boot:

- `zygote`, `system_server`, `surfaceflinger`, `audioserver`, `netd`,
  `wpa_supplicant`, and `biscuit-ledd` stay running.
- `/system/bin/biscuit_service` is present for the full Android control bridge.
- The full Android framework, Bluetooth A2DP sink, and framework audio paths
  are present. They are not part of the minimal checklist.

### Full Wi-Fi after provisioning

A Data wipe intentionally removes saved networks. Immediately after that wipe,
`wpa_supplicant` may be running while Wi-Fi is disconnected and has no DHCP
lease; this is not a boot failure. Validate connectivity only after provisioning
a network:

```sh
adb shell 'ip addr show wlan0; ip route'
adb shell 'ping -c 2 -W 2 <gateway>; ping -c 2 -W 2 8.8.8.8; ping -c 2 -W 2 google.com'
```

Expected after successful provisioning:

- `wlan0` has an IPv4 address and a default route through the local gateway.
- Gateway, Internet-IP, and DNS-name pings succeed.

## Framework-free minimal product

Scope: `biscuit_minimal-userdebug` built with `make minimal`.

The minimal product deliberately has no `zygote`, `system_server`,
`surfaceflinger`, `audioserver`, APKs, `/system/framework`, Java
`BiscuitService`, or Bluetooth framework/audio stack. Their absence is correct.

```sh
adb shell '
  for service in logd ledcontroller wmt_launcher wpa_supplicant servicemanager netd; do
    printf "%s=" "$service"; getprop "init.svc.$service"
  done
  for tool in wpa_connect wpa_passphrase wpa_cli ping ping6 ip netd ndc dhcpcd-run-hooks; do
    command -v "$tool" || exit 1
  done
  echo "apks=$(find /system/app /system/priv-app -type f 2>/dev/null | wc -l)"
  echo "framework=$(find /system/framework -type f 2>/dev/null | wc -l)"
  readlink /system/etc/ssl/certs
'
```

Expected after boot:

- `logd`, `ledcontroller`, `wmt_launcher`, `wpa_supplicant`,
  `servicemanager`, and `netd` are running.
- The listed Wi-Fi, DNS, and network tools are executable.
- APK and `/system/framework` file counts are zero.
- `/system/etc/ssl/certs` resolves to `../security/cacerts`, the single Android
  certificate store.
- `ledcontroller` is the replaceable non-oneshot slot; it disables the kernel
  boot animation, shows its short green indication, then leaves the ring off.
- `/dev/stpbt` is exposed for raw Bluetooth hardware access, but the minimal
  image intentionally does not provide a Bluetooth framework or Bluetooth audio.

### Minimal Wi-Fi after a Data wipe

A clean wipe intentionally leaves no saved network. The valid unprovisioned
state is a running `wpa_supplicant`, zero saved networks, no DHCP lease, and no
IP address. Do not classify that state as a boot failure.

Provision through the supported noninteractive helper without printing the PSK:

```sh
adb shell wpa_connect '<ssid>' '<8-to-63-character-passphrase-or-64-hex-psk>'
adb shell 'wpa_cli -i wlan0 status; ip addr show wlan0; ip route'
adb shell 'ping -c 2 -W 2 <gateway>; ping -c 2 -W 2 8.8.8.8; ping -c 2 -W 2 google.com'
```

Expected after successful provisioning:

- `wpa_cli` reports `wpa_state=COMPLETED`.
- `wlan0` has an IPv4 address and default route.
- DHCP publishes DNS to `netd`; gateway, Internet-IP, and DNS-name pings work.

## Non-blocking warnings

The following do not invalidate a matching product baseline unless they cause a
real symptom:

- permissive-SELinux `avc: denied` messages;
- `wpa_driver_nl80211_driver_cmd` or batched-scan warnings after connectivity
  works;
- non-blocking MT8163 device-tree warnings such as missing MFG/auxadc/RTC
  nodes.

## Real failure criteria

Investigate when the applicable product fails any of these conditions:

- ADB does not return after a reasonable manual boot period.
- `sys.boot_completed` does not reach `1`, or the device boot-loops/reboots.
- `/system` is absent or `/data`/`/cache` is not mounted `rw`.
- A required service for the selected product dies or repeatedly restarts.
- A provisioned Wi-Fi network cannot obtain an IP/default route or ping its
  gateway.
- A new kernel panic or oops appears.
