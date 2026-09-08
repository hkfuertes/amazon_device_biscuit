#!/system/bin/sh
# Small root-ADB controls for the framework-free EchoLocal image.
set -eu

state=/data/misc/echolocal
key=$state/psk
wpa_cli=/system/bin/wpa_cli
wpa_sockets=/data/misc/wifi/sockets

fail() {
    echo "echolocal: $*" >&2
    exit 1
}

require_root() {
    case "$(id)" in
        uid=0\(*) ;;
        *) fail 'requires root ADB' ;;
    esac
}

ensure_state() {
    mkdir -p "$state"
    chown root:system "$state"
    chmod 0770 "$state"
}

write_key() {
    tmp=$state/.psk.$$
    umask 077
    # ponytail: generate once on-device; use key rotate for an explicit replacement.
    /system/xbin/busybox dd if=/dev/urandom bs=32 count=1 2>/dev/null |
        /system/xbin/base64 > "$tmp"
    [ "$(/system/xbin/busybox wc -c < "$tmp")" = 45 ] || {
        rm -f "$tmp"
        fail 'could not generate a 32-byte key'
    }
    chown root:system "$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" "$key"
}

key_ensure() {
    ensure_state
    if [ ! -s "$key" ]; then
        write_key
    fi
    chown root:system "$key"
    chmod 0600 "$key"
}

key_show() {
    [ -s "$key" ] || fail "no key at $key"
    cat "$key"
}

key_rotate() {
    ensure_state
    write_key
    setprop ctl.restart ledcontroller
    echo 'Update Home Assistant with this new key:' >&2
    key_show
}

wifi_cli() {
    output="$("$wpa_cli" -iwlan0 -p"$wpa_sockets" "$@" 2>&1)" || {
        printf '%s\n' "$output" >&2
        return 1
    }
    case "$output" in
        *FAIL*) printf '%s\n' "$output" >&2; return 1 ;;
    esac
    printf '%s\n' "$output"
}

wifi_ok() {
    wifi_cli "$@" >/dev/null || fail "wpa_cli $1 failed"
}

status_value() {
    printf '%s\n' "$1" |
        /system/xbin/awk -F= -v wanted="$2" '$1 == wanted { sub(/^[^=]*=/, ""); print; exit }'
}

wifi_status() {
    status="$(wifi_cli status)" || fail 'cannot read Wi-Fi status'
    for field in wpa_state ssid ip_address; do
        value="$(status_value "$status" "$field")"
        [ -z "$value" ] || printf '%s=%s\n' "$field" "$value"
    done
}

remove_ssid() {
    ids="$(wifi_cli list_networks | /system/xbin/awk -F '\t' -v wanted="$1" 'NR > 1 && $2 == wanted { print $1 }')" ||
        fail 'cannot list saved networks'
    for network_id in $ids; do
        wifi_ok remove_network "$network_id"
    done
}

is_hex_key() {
    [ "${#1}" -eq 64 ] || return 1
    case "$1" in
        *[!0123456789abcdefABCDEF]*) return 1 ;;
    esac
    return 0
}

read_passphrase() {
    [ -t 0 ] || fail 'wifi connect needs an interactive ADB shell'
    printf 'Passphrase: ' >&2
    /system/xbin/stty -echo
    trap '/system/xbin/stty echo; printf "\n" >&2' EXIT HUP INT TERM
    IFS= read -r passphrase || {
        /system/xbin/stty echo
        trap - EXIT HUP INT TERM
        fail 'could not read passphrase'
    }
    /system/xbin/stty echo
    trap - EXIT HUP INT TERM
    printf '\n' >&2
}

derive_psk() {
    if is_hex_key "$passphrase"; then
        psk=$passphrase
    else
        [ "${#passphrase}" -ge 8 ] && [ "${#passphrase}" -le 63 ] ||
            fail 'WPA passphrase must contain 8 to 63 characters'
        psk="$(printf '%s\n' "$passphrase" |
            /system/bin/wpa_passphrase "$ssid" |
            /system/xbin/awk -F= '/^[[:space:]]*psk=[0-9a-fA-F]+$/ { sub(/^[[:space:]]*psk=/, ""); print; exit }')"
    fi
    unset passphrase
    is_hex_key "$psk" || fail 'could not derive a WPA PSK'
}

wait_for_wifi() {
    attempts=0
    while [ "$attempts" -lt 30 ]; do
        status="$(wifi_cli status)" || return 1
        [ "$(status_value "$status" wpa_state)" = COMPLETED ] &&
            [ "$(status_value "$status" ssid)" = "$ssid" ] && break
        attempts=$((attempts + 1))
        sleep 1
    done
    [ "$(status_value "$status" wpa_state)" = COMPLETED ] || return 1
    [ "$(status_value "$status" ssid)" = "$ssid" ] || return 1

    # The monitor normally starts DHCP on CONNECTED; restart once to cover a missed event.
    setprop ctl.restart dhcpcd_wlan0
    attempts=0
    while [ "$attempts" -lt 15 ]; do
        status="$(wifi_cli status)" || return 1
        ip_address="$(status_value "$status" ip_address)"
        [ -n "$ip_address" ] && return 0
        attempts=$((attempts + 1))
        sleep 1
    done
    return 1
}

wifi_connect() {
    ssid=$1
    mode=$2
    [ -n "$ssid" ] || fail 'SSID must not be empty'
    ssid_hex="$(printf '%s' "$ssid" | /system/xbin/od -An -tx1 | /system/xbin/tr -d ' \n')"
    [ -n "$ssid_hex" ] || fail 'SSID must not be empty'

    if [ "$mode" = psk ]; then
        read_passphrase
        derive_psk
    fi

    remove_ssid "$ssid"
    network_id="$(wifi_cli add_network | /system/xbin/awk 'NF { id = $0 } END { print id }')" ||
        fail 'could not add network'
    case "$network_id" in
        ''|*[!0-9]*) fail 'wpa_cli returned an invalid network id' ;;
    esac

    wifi_ok set_network "$network_id" ssid "$ssid_hex"
    wifi_ok set_network "$network_id" scan_ssid 1
    if [ "$mode" = psk ]; then
        wifi_ok set_network "$network_id" psk "$psk"
        unset psk
    else
        wifi_ok set_network "$network_id" key_mgmt NONE
    fi
    wifi_ok enable_network "$network_id"
    wifi_ok select_network "$network_id"
    wifi_ok save_config

    if ! wait_for_wifi; then
        wifi_cli remove_network "$network_id" >/dev/null || true
        wifi_cli save_config >/dev/null || true
        fail "did not connect to $ssid"
    fi
    printf 'connected: %s (%s)\n' "$ssid" "$(status_value "$status" ip_address)"
}

usage() {
    cat >&2 <<'EOF'
Usage:
  echolocal key show|rotate
  echolocal wifi status
  echolocal wifi connect <ssid>
  echolocal wifi open <ssid>
EOF
    exit 2
}

require_root
case "${1:-}" in
    key)
        case "${2:-}" in
            ensure) key_ensure ;;
            show) key_show ;;
            rotate) key_rotate ;;
            *) usage ;;
        esac
        ;;
    wifi)
        case "${2:-}" in
            status) wifi_status ;;
            connect) [ "$#" -eq 3 ] || usage; wifi_connect "$3" psk ;;
            open) [ "$#" -eq 3 ] || usage; wifi_connect "$3" open ;;
            *) usage ;;
        esac
        ;;
    *) usage ;;
esac
