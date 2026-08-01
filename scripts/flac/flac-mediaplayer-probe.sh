#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
CM12="$ROOT/workspace/cm12"
DEX=/tmp/FlacMediaPlayerProbe.dex
CLASSES=/tmp/flac-mediaplayer-probe-classes
FLAC=/tmp/flac-probe.flac

ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i 'sine=frequency=880:duration=1.2:sample_rate=16000' \
  -ac 1 "$FLAC"

docker run --rm \
  -v "$ROOT:$ROOT" \
  -v /tmp:/host-tmp \
  -w "$CM12" \
  cm12-ubuntu14:latest \
  bash -lc 'set -e; FRAME=$(find out-docker -path "*framework_intermediates/classes.jar" | head -1); test -n "$FRAME"; rm -rf /tmp/flac-mediaplayer-probe-classes; mkdir -p /tmp/flac-mediaplayer-probe-classes; javac -source 1.7 -target 1.7 -cp "$FRAME" -d /tmp/flac-mediaplayer-probe-classes "$PWD/../../scripts/flac/FlacMediaPlayerProbe.java"; out-docker/host/linux-x86/bin/dx --dex --output=/host-tmp/FlacMediaPlayerProbe.dex /tmp/flac-mediaplayer-probe-classes'

adb push "$FLAC" /data/local/tmp/flac-probe.flac >/dev/null
adb push "$DEX" /data/local/tmp/FlacMediaPlayerProbe.dex >/dev/null
adb shell 'CLASSPATH=/data/local/tmp/FlacMediaPlayerProbe.dex app_process /system/bin FlacMediaPlayerProbe /data/local/tmp/flac-probe.flac'
