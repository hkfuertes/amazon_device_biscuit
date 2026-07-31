#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
CM12="$ROOT/workspace/cm12"
DEX=/tmp/FlacMediaCodecProbe.dex
CLASSES=/tmp/flac-mediacodec-probe-classes

# Requires an existing CM12 out-docker tree; does not write generated files to git.
docker run --rm \
  -v "$ROOT:$ROOT" \
  -v /tmp:/host-tmp \
  -w "$CM12" \
  cm12-ubuntu14:latest \
  bash -lc 'set -e; FRAME=$(find out-docker -path "*framework_intermediates/classes.jar" | head -1); test -n "$FRAME"; rm -rf /tmp/flac-mediacodec-probe-classes; mkdir -p /tmp/flac-mediacodec-probe-classes; javac -source 1.7 -target 1.7 -cp "$FRAME" -d /tmp/flac-mediacodec-probe-classes "$PWD/../../scripts/flac/FlacMediaCodecProbe.java"; out-docker/host/linux-x86/bin/dx --dex --output=/host-tmp/FlacMediaCodecProbe.dex /tmp/flac-mediacodec-probe-classes'

adb push "$DEX" /data/local/tmp/FlacMediaCodecProbe.dex >/dev/null
adb shell 'CLASSPATH=/data/local/tmp/FlacMediaCodecProbe.dex app_process /system/bin FlacMediaCodecProbe'
