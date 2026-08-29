#!/usr/bin/env bash
# Smoke-test canonical tracked trees stage into a disposable CM12 checkout.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CM12="$TMP/cm12"
mkdir -p "$CM12/build"

[[ ! -e "$REPO_ROOT/sources" ]] || { echo "legacy sources/ tree remains" >&2; exit 1; }
CM12="$CM12" "$REPO_ROOT/scripts/stage-tree.sh" >/dev/null

for path in \
  device/amazon/biscuit/AndroidProducts.mk \
  device/amazon/mt8163-common/mt8163-common.mk \
  hardware/amazon/audio/Android.mk \
  hardware/mediatek/wlan/wifi_hal/Android.mk; do
  [[ -f "$CM12/$path" ]] || { echo "missing staged $path" >&2; exit 1; }
done

echo "PASS canonical trees staged"
