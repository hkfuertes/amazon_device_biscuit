#!/usr/bin/env bash
# Smoke-test canonical tracked trees stage into a disposable CM12 checkout.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CM12="$TMP/cm12"
artifact="$TMP/echod"
models="$TMP/models"
mkdir -p "$CM12/build" "$models"
printf 'echod fixture\n' > "$artifact"
for model in okay_nabu hey_jarvis hey_mycroft; do
  printf '%s manifest\n' "$model" > "$models/$model.json"
  printf '%s model\n' "$model" > "$models/$model.tflite"
done

[[ ! -e "$REPO_ROOT/sources" ]] || { echo "legacy sources/ tree remains" >&2; exit 1; }
CM12="$CM12" ECHOLOCAL_ARTIFACT="$artifact" ECHOLOCAL_MODEL_DIR="$models" \
  "$REPO_ROOT/scripts/stage-tree.sh" >/dev/null

for path in \
  device/amazon/biscuit/AndroidProducts.mk \
  device/amazon/biscuit/echolocal/echod \
  device/amazon/biscuit/echolocal/models/okay_nabu.json \
  device/amazon/biscuit/echolocal/models/okay_nabu.tflite \
  device/amazon/biscuit/echolocal/models/hey_jarvis.json \
  device/amazon/biscuit/echolocal/models/hey_jarvis.tflite \
  device/amazon/biscuit/echolocal/models/hey_mycroft.json \
  device/amazon/biscuit/echolocal/models/hey_mycroft.tflite \
  device/amazon/mt8163-common/mt8163-common.mk \
  hardware/amazon/audio/Android.mk \
  hardware/mediatek/wlan/wifi_hal/Android.mk; do
  [[ -f "$CM12/$path" ]] || { echo "missing staged $path" >&2; exit 1; }
done

echo "PASS canonical trees staged"
