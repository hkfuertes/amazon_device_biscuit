#!/usr/bin/env bash
# Materialize a tiny local Amazon-release fixture without touching this repo's workspace.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE_REPO="$TMP/repo"
mkdir -p "$FAKE_REPO/scripts" \
  "$TMP/platform/kernel/mediatek/mt8163/3.18/arch/arm64/configs" \
  "$TMP/support/prebuilt" \
  "$TMP/release"
cp "$REPO_ROOT/scripts/prepare-kernel-source.sh" "$FAKE_REPO/scripts/"
printf 'all:\n' > "$TMP/platform/kernel/mediatek/mt8163/3.18/Makefile"
printf 'CONFIG_TEST=y\n' > "$TMP/platform/kernel/mediatek/mt8163/3.18/arch/arm64/configs/biscuit_defconfig"
printf 'header\n' > "$TMP/support/prebuilt/header"
tar -C "$TMP/platform" -cf "$TMP/release/platform.tar" kernel
tar -C "$TMP/support" -czf "$TMP/release/build_kernel.tar.gz" prebuilt
tar -C "$TMP/release" -cjf "$TMP/kernel-fixture.tar.bz2" platform.tar build_kernel.tar.gz
SHA="$(sha256sum "$TMP/kernel-fixture.tar.bz2" | awk '{print $1}')"
URL="file://$TMP/kernel-fixture.tar.bz2"

AMAZON_SOURCE_URL="$URL" AMAZON_SOURCE_SHA256="$SHA" \
  "$FAKE_REPO/scripts/prepare-kernel-source.sh" >/dev/null
BASE="$FAKE_REPO/workspace/kernel/amazon/biscuit"
SUPPORT="$FAKE_REPO/workspace/kernel/amazon/biscuit-build-support"
META="$FAKE_REPO/workspace/kernel/amazon/biscuit-source.md"
[[ -f "$BASE/Makefile" && -f "$BASE/arch/arm64/configs/biscuit_defconfig" ]]
[[ -f "$SUPPORT/prebuilt/header" && -f "$META" && ! -e "$BASE/README.md" ]]
grep -q "SHA256: $SHA" "$META"

if AMAZON_SOURCE_URL="$URL" AMAZON_SOURCE_SHA256="$(printf '0%.0s' {1..64})" \
  "$FAKE_REPO/scripts/prepare-kernel-source.sh" >/dev/null 2>&1; then
  echo 'wrong kernel SHA unexpectedly accepted' >&2
  exit 1
fi

echo 'PASS kernel source is verified and materialized without local changes'
