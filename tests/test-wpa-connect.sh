#!/usr/bin/env bash
# Exercise the minimal WPA provisioning helper without touching a device.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER="$ROOT/device/amazon/biscuit/rootdir/wpa_connect"
HOST_BUSYBOX="$(command -v busybox)"
[[ -n "$HOST_BUSYBOX" ]] || { echo 'missing host BusyBox' >&2; exit 1; }
[[ -x "$HELPER" ]] || { echo "missing executable: $HELPER" >&2; exit 1; }
grep -Fq 'return 0' "$HELPER"
! grep -Fq 'read -r' "$HELPER"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SYSTEM="$TMP/system"
WPA_LOG="$TMP/wpa.log"
PASSPHRASE_LOG="$TMP/wpa-passphrase.log"
PROP_LOG="$TMP/properties.log"
mkdir -p "$SYSTEM/bin" "$SYSTEM/xbin"

python3 - "$HELPER" "$SYSTEM/bin/wpa_connect" "$SYSTEM" "$TMP" <<'PY'
import pathlib
import sys
source = pathlib.Path(sys.argv[1]).read_text()
system = sys.argv[3]
tmp = sys.argv[4]
for old, new in {
    '/system/xbin/busybox': system + '/xbin/busybox',
    '/system/bin/wpa_cli': system + '/bin/wpa_cli',
    '/system/bin/wpa_passphrase': system + '/bin/wpa_passphrase',
    '/system/bin/setprop': system + '/bin/setprop',
    '/data/misc/wifi/sockets': tmp + '/sockets',
}.items():
    source = source.replace(old, new)
pathlib.Path(sys.argv[2]).write_text(source)
PY
chmod 0755 "$SYSTEM/bin/wpa_connect"

cat > "$SYSTEM/xbin/busybox" <<EOF
#!/bin/sh
case "\${1:-}" in
    id) [ "\${2:-}" = -u ] && printf '0\\n' ;;
    *) exec "$HOST_BUSYBOX" "\$@" ;;
esac
EOF
chmod 0755 "$SYSTEM/xbin/busybox"

cat > "$SYSTEM/bin/wpa_cli" <<'EOF'
#!/bin/sh
set -eu
while [ "$#" -gt 0 ]; do
    case "$1" in
        -i*|-p*) shift ;;
        *) command=$1; shift; break ;;
    esac
done
printf '%s' "$command" >> "$TEST_WPA_LOG"
for argument in "$@"; do printf ' %s' "$argument" >> "$TEST_WPA_LOG"; done
printf '\n' >> "$TEST_WPA_LOG"
case "$command" in
    list_networks) printf '%s\n' 'network id / ssid / bssid / flags' ;;
    add_network) printf '0\n' ;;
    status) printf '%s\n' 'wpa_state=COMPLETED' 'ssid=Strongs' 'ip_address=192.0.2.1' ;;
    set_network|enable_network|select_network|save_config|remove_network) printf 'OK\n' ;;
    *) exit 1 ;;
esac
EOF
chmod 0755 "$SYSTEM/bin/wpa_cli"

cat > "$SYSTEM/bin/wpa_passphrase" <<'EOF'
#!/bin/sh
set -eu
[ "$#" -eq 1 ]
[ "$1" = Strongs ]
IFS= read -r passphrase
[ "$passphrase" = "$TEST_SECRET" ]
printf '%s\n' "$1" >> "$TEST_WPA_PASSPHRASE_LOG"
printf '%s\n' 'network={' '    psk=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' '}'
EOF
chmod 0755 "$SYSTEM/bin/wpa_passphrase"

cat > "$SYSTEM/bin/setprop" <<'EOF'
#!/bin/sh
printf '%s=%s\n' "$1" "$2" >> "$TEST_PROPERTY_LOG"
EOF
chmod 0755 "$SYSTEM/bin/setprop"

: > "$WPA_LOG"
: > "$PASSPHRASE_LOG"
: > "$PROP_LOG"
secret=12345678
output=$(TEST_WPA_LOG="$WPA_LOG" TEST_WPA_PASSPHRASE_LOG="$PASSPHRASE_LOG" TEST_PROPERTY_LOG="$PROP_LOG" TEST_SECRET="$secret" sh "$SYSTEM/bin/wpa_connect" Strongs "$secret")
[[ "$output" == 'connected: Strongs (192.0.2.1)' ]]
grep -Fxq 'Strongs' "$PASSPHRASE_LOG"
grep -Fxq 'set_network 0 ssid 5374726f6e6773' "$WPA_LOG"
grep -Fxq 'set_network 0 key_mgmt WPA-PSK' "$WPA_LOG"
grep -Fxq 'set_network 0 psk 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' "$WPA_LOG"
grep -Fxq 'ctl.restart=dhcpcd_wlan0' "$PROP_LOG"
! grep -Fq "$secret" "$WPA_LOG"

: > "$PASSPHRASE_LOG"
raw_psk=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
output=$(TEST_WPA_LOG="$WPA_LOG" TEST_WPA_PASSPHRASE_LOG="$PASSPHRASE_LOG" TEST_PROPERTY_LOG="$PROP_LOG" TEST_SECRET=unused sh "$SYSTEM/bin/wpa_connect" Strongs "$raw_psk")
[[ "$output" == 'connected: Strongs (192.0.2.1)' ]]
[[ ! -s "$PASSPHRASE_LOG" ]]

status=$(TEST_WPA_LOG="$WPA_LOG" TEST_WPA_PASSPHRASE_LOG="$PASSPHRASE_LOG" TEST_PROPERTY_LOG="$PROP_LOG" TEST_SECRET=unused sh "$SYSTEM/bin/wpa_connect" status)
[[ "$status" == $'wpa_state=COMPLETED\nssid=Strongs\nip_address=192.0.2.1' ]]

echo 'wpa_connect checks passed (no device required)'
