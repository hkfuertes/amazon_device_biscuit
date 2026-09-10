#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUBMODULE="prebuilts/android_prebuilts_webview_chromium_arm"
REV="3030c7f0da67e0e207ea0b280cc4360762c70f24"
URL="https://github.com/hkfuertes/android_prebuilts_webview_chromium_arm.git"
PRODUCT="$ROOT/device/amazon/biscuit/cm_biscuit.mk"
STAGE="$ROOT/scripts/stage-tree.sh"

[[ -x "$ROOT/$SUBMODULE/verify.sh" ]]
"$ROOT/$SUBMODULE/verify.sh"
test "$(git -C "$ROOT/$SUBMODULE" rev-parse HEAD)" = "$REV"
test "$(git -C "$ROOT" config -f .gitmodules --get "submodule.$SUBMODULE.url")" = "$URL"
git -C "$ROOT" ls-files --stage -- "$SUBMODULE" | grep -Eq "^160000 $REV 0[[:space:]]+$SUBMODULE$"
grep -Fq 'PRODUCT_PREBUILT_WEBVIEWCHROMIUM := yes' "$PRODUCT"
grep -Fq '    webview' "$PRODUCT"
grep -Fq 'submodule update --init -- "$WEBVIEW_PREBUILT_REL"' "$STAGE"
grep -Fq 'git -C "$WEBVIEW_PREBUILT" lfs pull' "$STAGE"
grep -Fq 'CM12 WebView prebuilt' "$STAGE"
! grep -Fq 'PRODUCT_PREBUILT_WEBVIEWCHROMIUM' "$ROOT/device/amazon/biscuit/biscuit_minimal.mk"

echo 'PASS full WebView prebuilt contract'
