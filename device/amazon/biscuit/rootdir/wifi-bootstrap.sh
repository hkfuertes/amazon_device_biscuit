#!/system/bin/sh
# Bootstrap MTK Wi-Fi and dispatch wpa_cli connection events without the framework.
set -eu

if [ "$#" -ne 0 ]; then
    [ "$#" -eq 2 ] && [ "$1" = wlan0 ] || exit 1
    case "$2" in
        CONNECTED) setprop ctl.restart dhcpcd_wlan0 ;;
        DISCONNECTED) setprop ctl.stop dhcpcd_wlan0 ;;
        *) exit 1 ;;
    esac
    exit 0
fi

setprop sys.biscuit.wifi.ready 0
config=/data/misc/wifi/wpa_supplicant.conf
if [ ! -e "$config" ]; then
    cp /system/etc/wifi/wpa_supplicant.conf "$config"
fi
chown wifi:wifi "$config"
chmod 0660 "$config"

# Init marks a service running before its binary finishes initialization.
# Wait for the loader to finish without blocking init's property processing.
attempts=0
while [ "$(getprop init.svc.wmtLoader)" != stopped ] || \
      [ "$(getprop init.svc.conn_launcher)" != running ]; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 10 ]; then
        echo 'WMT services did not become ready' >&2
        exit 1
    fi
    sleep 1
done

# conn_launcher reports running before WMT/STP is ready for a radio request.
radio_settle_seconds=5
sleep "$radio_settle_seconds"

# Same power-on operation as CM12's wifi_load_driver(); the driver is built in.
printf 1 > /dev/wmtWifi
if [ ! -d /sys/class/net/wlan0 ]; then
    echo 'wlan0 did not appear after WMT Wi-Fi power-on' >&2
    exit 1
fi
setprop sys.biscuit.wifi.ready 1

# Request one scan after init creates the supplicant control socket.
scan_attempts=0
until /system/bin/wpa_cli -iwlan0 -p/data/misc/wifi/sockets scan >/dev/null 2>&1; do
    scan_attempts=$((scan_attempts + 1))
    if [ "$scan_attempts" -ge 10 ]; then
        echo 'wpa_supplicant did not accept initial scan' >&2
        exit 1
    fi
    sleep 1
done

# The first CONNECTED event can precede the wpa_cli action monitor.
association_attempts=0
until /system/bin/wpa_cli -iwlan0 -p/data/misc/wifi/sockets status 2>/dev/null | grep -q '^wpa_state=COMPLETED$'; do
    association_attempts=$((association_attempts + 1))
    if [ "$association_attempts" -ge 15 ]; then
        echo 'wpa_supplicant did not complete initial association' >&2
        exit 1
    fi
    sleep 1
done
setprop ctl.restart dhcpcd_wlan0
