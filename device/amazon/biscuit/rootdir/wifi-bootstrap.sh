#!/system/bin/sh
# Framework-free Wi-Fi bootstrap for Biscuit CM14.1 minimal.
set -u

WPA_CLI=/system/bin/wpa_cli
WPA_SOCKETS=/data/misc/wifi/sockets
DATA_CONF=/data/misc/wifi/wpa_supplicant.conf
SYSTEM_CONF=/system/etc/wifi/wpa_supplicant.conf

if [ "$#" -ne 0 ]; then
    [ "$#" -eq 2 ] && [ "$1" = wlan0 ] || exit 1
    case "$2" in
        CONNECTED) setprop ctl.restart dhcpcd_wlan0 ;;
        DISCONNECTED) setprop ctl.stop dhcpcd_wlan0 ;;
        *) exit 1 ;;
    esac
    exit 0
fi

wifi_cli() {
    "$WPA_CLI" -iwlan0 -p"$WPA_SOCKETS" "$@" >/dev/null 2>&1
}

seed_config() {
    mkdir -p /data/misc/wifi /data/misc/wifi/sockets /data/misc/wpa_supplicant
    chown wifi:wifi /data/misc/wifi /data/misc/wifi/sockets /data/misc/wpa_supplicant 2>/dev/null || true
    chmod 0770 /data/misc/wifi /data/misc/wifi/sockets /data/misc/wpa_supplicant 2>/dev/null || true
    if [ ! -s "$DATA_CONF" ]; then
        if [ -r "$SYSTEM_CONF" ]; then
            cat "$SYSTEM_CONF" >"$DATA_CONF"
        else
            printf 'ctrl_interface=/data/misc/wifi/sockets\nupdate_config=1\nap_scan=1\n' >"$DATA_CONF"
        fi
    fi
    chown wifi:wifi "$DATA_CONF" 2>/dev/null || true
    chmod 0660 "$DATA_CONF" 2>/dev/null || true
}

has_saved_network() {
    networks=$("$WPA_CLI" -iwlan0 -p"$WPA_SOCKETS" list_networks 2>/dev/null) || return 2
    case "$networks" in
        *FAIL*) return 2 ;;
    esac
    old_ifs=$IFS
    IFS='
'
    for line in $networks; do
        case "$line" in
            [0-9]*[[:space:]]*) IFS=$old_ifs; return 0 ;;
        esac
    done
    IFS=$old_ifs
    return 1
}

scan() {
    attempts=0
    while [ "$attempts" -lt 10 ]; do
        wifi_cli scan && return 0
        attempts=$((attempts + 1))
        sleep 1
    done
    return 1
}

associate() {
    wifi_cli reconnect || wifi_cli reassociate || return 1
    attempts=0
    while [ "$attempts" -lt 30 ]; do
        status=$("$WPA_CLI" -iwlan0 -p"$WPA_SOCKETS" status 2>/dev/null || true)
        case "$status" in
            *wpa_state=COMPLETED*) return 0 ;;
        esac
        attempts=$((attempts + 1))
        sleep 1
    done
    return 1
}

seed_config
# MTK WMT/STP can report ready before WLAN creation is actually usable.
sleep 5

max_radio_attempts=3
radio_attempt=1
while [ "$radio_attempt" -le "$max_radio_attempts" ]; do
    printf 1 >/dev/wmtWifi 2>/dev/null || true
    setprop wlan.driver.status ok
    if [ ! -d /sys/class/net/wlan0 ]; then
        echo 'wlan0 did not appear after WMT Wi-Fi power-on' >&2
    else
        setprop sys.biscuit.wifi.ready 1
        if scan; then
            has_saved_network
            saved=$?
            if [ "$saved" -eq 0 ]; then
                if associate; then
                    setprop ctl.restart dhcpcd_wlan0
                    exit 0
                fi
            elif [ "$saved" -eq 1 ]; then
                # No saved network after a wipe: keep wpa_supplicant alive for provisioning.
                exit 0
            fi
        fi
    fi
    setprop sys.biscuit.wifi.ready 0
    setprop ctl.stop wpa_supplicant
    printf 0 >/dev/wmtWifi 2>/dev/null || true
    echo "Wi-Fi radio attempt $radio_attempt failed; retrying" >&2
    sleep 5
    radio_attempt=$((radio_attempt + 1))
done

exit 1
