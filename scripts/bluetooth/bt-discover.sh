#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
CM12="$ROOT/workspace/cm12"
SECONDS_TO_SCAN="${1:-20}"
DEX=/tmp/BtDiscover.dex
CLASSES=/tmp/btdiscover-classes

# Requires an existing CM12 out-docker tree; does not write generated files to git.
docker run --rm \
  -v "$ROOT:$ROOT" \
  -v /tmp:/host-tmp \
  -w "$CM12" \
  cm12-ubuntu14:latest \
  bash -lc 'set -e; FRAME=$(find out-docker -path "*framework_intermediates/classes.jar" | head -1); rm -rf /tmp/btdiscover-classes; mkdir -p /tmp/btdiscover-classes; javac -source 1.7 -target 1.7 -cp "$FRAME" -d /tmp/btdiscover-classes "../scripts/bluetooth/BtDiscover.java"; out-docker/host/linux-x86/bin/dx --dex --output=/host-tmp/BtDiscover.dex /tmp/btdiscover-classes'

adb push "$DEX" /data/local/tmp/BtDiscover.dex >/dev/null
adb shell "CLASSPATH=/data/local/tmp/BtDiscover.dex app_process /system/bin BtDiscover '$SECONDS_TO_SCAN'"
