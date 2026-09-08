#!/usr/bin/env bash
# Exercise the bootstrap and wpa_cli action callback without touching a device.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export TEST_WIFI_ROOT="$tmp/fs" TEST_PROPERTY_LOG="$tmp/properties" TEST_RADIO_MODE=delayed
export TEST_WPA_LOG="$tmp/wpa-commands" TEST_WPA_STATE="$tmp/wpa-state"
: > "$TEST_WPA_LOG"
printf 'association-delayed\n' > "$TEST_WPA_STATE"
mkdir -p "$TEST_WIFI_ROOT"/{system/etc/wifi,data/misc/wifi,dev,sys/class/net/wlan0}
printf 'ctrl_interface=/data/misc/wifi/sockets\n' > "$TEST_WIFI_ROOT/system/etc/wifi/wpa_supplicant.conf"

# Redirect filesystem paths only; run the real script logic with mocked Android commands.
python3 - "$ROOT/device/amazon/biscuit/rootdir/wifi-bootstrap.sh" "$tmp/run.sh" "$TEST_WIFI_ROOT" <<'PY'
import pathlib
import sys
source = pathlib.Path(sys.argv[1]).read_text()
source = source.replace('/system/bin/wpa_cli', 'wpa_cli')
for prefix in ('/system/', '/data/', '/dev/', '/sys/'):
    source = source.replace(prefix, sys.argv[3] + prefix)
pathlib.Path(sys.argv[2]).write_text(source)
PY
getprop() {
    case "$1" in
        init.svc.wmtLoader)
            if [[ "$TEST_RADIO_MODE" == ready ]]; then echo stopped; else echo running; fi ;;
        init.svc.conn_launcher) echo running ;;
        *) return 1 ;;
    esac
}
setprop() { printf '%s=%s\n' "$1" "$2" >> "$TEST_PROPERTY_LOG"; }
chown() { [[ "$#" == 2 && "$1" == wifi:wifi && "$2" == "$TEST_WIFI_ROOT/data/misc/wifi/wpa_supplicant.conf" ]]; }
sleep() {
    printf '%s\n' "$1" >> "$tmp/waits"
    if [[ "$TEST_RADIO_MODE" == delayed ]]; then TEST_RADIO_MODE=ready; fi
}
wpa_cli() {
    local command="${@: -1}" state
    printf '%s\n' "$command" >> "$TEST_WPA_LOG"
    case "$command" in
        scan) return 0 ;;
        status)
            state="$(<"$TEST_WPA_STATE")"
            if [[ "$state" == association-delayed ]]; then
                printf 'associated\n' > "$TEST_WPA_STATE"
                printf 'wpa_state=DISCONNECTED\n'
            elif [[ "$state" == never ]]; then
                printf 'wpa_state=DISCONNECTED\n'
            else
                printf 'wpa_state=COMPLETED\n'
            fi
            ;;
        *) return 1 ;;
    esac
}
export tmp
export -f getprop setprop chown sleep wpa_cli

bash "$tmp/run.sh"
[[ "$(<"$TEST_WIFI_ROOT/dev/wmtWifi")" == 1 ]]
[[ "$(tr '\n' ' ' < "$tmp/waits")" == '1 5 1 ' ]]
[[ "$(<"$TEST_WPA_LOG")" == $'scan\nstatus\nstatus' ]]
grep -Fxq 'sys.biscuit.wifi.ready=1' "$TEST_PROPERTY_LOG"
grep -Fxq 'ctl.restart=dhcpcd_wlan0' "$TEST_PROPERTY_LOG"
cmp "$TEST_WIFI_ROOT/system/etc/wifi/wpa_supplicant.conf" "$TEST_WIFI_ROOT/data/misc/wifi/wpa_supplicant.conf"

# A saved network survives boot; its expected ownership/mode is repaired.
printf 'saved-network-placeholder\n' > "$TEST_WIFI_ROOT/data/misc/wifi/wpa_supplicant.conf"
chmod 0600 "$TEST_WIFI_ROOT/data/misc/wifi/wpa_supplicant.conf"
bash "$tmp/run.sh"
[[ "$(<"$TEST_WIFI_ROOT/data/misc/wifi/wpa_supplicant.conf")" == saved-network-placeholder ]]
[[ "$(stat -c %a "$TEST_WIFI_ROOT/data/misc/wifi/wpa_supplicant.conf")" == 660 ]]

# Initial association is bounded and must not start DHCP before COMPLETED.
export TEST_RADIO_MODE=ready
printf 'never\n' > "$TEST_WPA_STATE"
: > "$TEST_PROPERTY_LOG"
: > "$tmp/waits"
if bash "$tmp/run.sh" > "$tmp/error" 2>&1; then echo 'accepted incomplete association' >&2; exit 1; fi
! grep -Fq 'ctl.restart=dhcpcd_wlan0' "$TEST_PROPERTY_LOG"
grep -Fq 'did not complete initial association' "$tmp/error"
[[ "$(grep -c '^1$' "$tmp/waits")" -lt 15 ]]

# A successful write alone is insufficient: require the actual network interface.
rmdir "$TEST_WIFI_ROOT/sys/class/net/wlan0"
: > "$TEST_PROPERTY_LOG"
if bash "$tmp/run.sh" > "$tmp/error" 2>&1; then echo 'accepted missing wlan0' >&2; exit 1; fi
! grep -Fq 'sys.biscuit.wifi.ready=1' "$TEST_PROPERTY_LOG"
grep -Fq 'wlan0 did not appear' "$tmp/error"

# A stuck launcher must not trigger power-on or an unbounded wait.
export TEST_RADIO_MODE=never
rm "$TEST_WIFI_ROOT/dev/wmtWifi"
: > "$tmp/waits"
if bash "$tmp/run.sh" > "$tmp/error" 2>&1; then echo 'accepted unready WMT' >&2; exit 1; fi
[[ ! -e "$TEST_WIFI_ROOT/dev/wmtWifi" ]]
[[ "$(grep -c '^1$' "$tmp/waits")" -lt 10 ]]
grep -Fq 'WMT services did not become ready' "$tmp/error"

: > "$TEST_PROPERTY_LOG"
bash "$tmp/run.sh" wlan0 CONNECTED
[[ "$(<"$TEST_PROPERTY_LOG")" == ctl.restart=dhcpcd_wlan0 ]]
: > "$TEST_PROPERTY_LOG"
bash "$tmp/run.sh" wlan0 DISCONNECTED
[[ "$(<"$TEST_PROPERTY_LOG")" == ctl.stop=dhcpcd_wlan0 ]]
: > "$TEST_PROPERTY_LOG"
if bash "$tmp/run.sh" wlan1 CONNECTED; then echo 'accepted unexpected interface' >&2; exit 1; fi
[[ ! -s "$TEST_PROPERTY_LOG" ]]

echo 'bootstrap Wi-Fi checks passed (no device required)'
