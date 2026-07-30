#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
CM12="$ROOT/workspace/cm12"
DEX=/tmp/WifiConnect.dex
CLASSES=/tmp/wificonnect-classes
SSID=${1:-}

if [[ -z "$SSID" ]]; then
  echo "usage: $0 <ssid>" >&2
  exit 2
fi

read -rsp "WiFi PSK: " PSK
echo >&2

# Build against the platform jar from the existing CM12 tree; no generated files go to git.
docker run --rm \
  -v "$ROOT:$ROOT" \
  -v /tmp:/host-tmp \
  -w "$CM12" \
  cm12-ubuntu14:latest \
  bash -lc 'set -e; FRAME=$(find out-docker -path "*framework_intermediates/classes.jar" | head -1); rm -rf /tmp/wificonnect-classes; mkdir -p /tmp/wificonnect-classes; javac -source 1.7 -target 1.7 -cp "$FRAME" -d /tmp/wificonnect-classes "../scripts/wifi/WifiConnect.java"; out-docker/host/linux-x86/bin/dx --dex --output=/host-tmp/WifiConnect.dex /tmp/wificonnect-classes'

adb push "$DEX" /data/local/tmp/WifiConnect.dex >/dev/null
{
  printf '%s\n' "$SSID"
  printf '%s\n' "$PSK"
} | adb shell 'CLASSPATH=/data/local/tmp/WifiConnect.dex app_process /system/bin WifiConnect'
