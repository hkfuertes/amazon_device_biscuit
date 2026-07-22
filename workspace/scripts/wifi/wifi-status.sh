#!/usr/bin/env bash
set -euo pipefail

adb shell '
echo "--- wifi framework ---"
dumpsys wifi 2>/dev/null | grep -Ei "Wi-Fi is|mNetworkInfo|mWifiInfo|SSID|Supplicant state|DHCP|ip|gateway" | head -80 || true
echo "--- connectivity ---"
dumpsys connectivity 2>/dev/null | grep -Ei "Active default network|NetworkAgentInfo|WIFI|CONNECTED|VALIDATED|LinkProperties|InterfaceName|Routes|DnsAddresses" | head -120 || true
echo "--- kernel view ---"
ip addr show wlan0
ip route show table all | grep -E "(^default| wlan0 |table wlan0)" || true
'
