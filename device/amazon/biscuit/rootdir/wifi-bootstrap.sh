#!/system/bin/sh
# Seed wpa_supplicant once; later provisioning owns this file.
set -eu

config=/data/misc/wifi/wpa_supplicant.conf
if [ ! -e "$config" ]; then
    cp /system/etc/wifi/wpa_supplicant.conf "$config"
    chown wifi wifi "$config"
    chmod 0660 "$config"
fi

setprop sys.biscuit.wifi.ready 1
