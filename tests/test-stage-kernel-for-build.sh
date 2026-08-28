#!/usr/bin/env bash
# Verify kernel patches affect only a disposable build stage.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BASE="$TMP/base"
SUPPORT="$TMP/support"
STAGE="$TMP/stage"
PATCH_DIR="$TMP/patches"
mkdir -p "$BASE/arch/arm64/configs" "$SUPPORT/prebuilt" "$PATCH_DIR"
printf 'all:\n' > "$BASE/Makefile"
printf 'CONFIG_TEST=y\n' > "$BASE/arch/arm64/configs/biscuit_defconfig"
printf 'before\n' > "$BASE/marker.txt"
printf 'header\n' > "$SUPPORT/prebuilt/header"

cat > "$PATCH_DIR/10-marker.patch" <<'PATCH'
--- a/one/two/three/marker.txt
+++ b/one/two/three/marker.txt
@@ -1 +1 @@
-before
+after
PATCH

KERNEL_BASE="$BASE" KERNEL_SUPPORT="$SUPPORT" KERNEL_STAGE="$STAGE" PATCH_DIR="$PATCH_DIR" \
  "$REPO_ROOT/scripts/stage-kernel-for-build.sh" >/dev/null
[[ "$(<"$BASE/marker.txt")" == before ]]
[[ "$(<"$STAGE/marker.txt")" == after ]]
[[ -f "$STAGE/amazon-build/prebuilt/header" ]]

if KERNEL_BASE="$BASE" KERNEL_SUPPORT="$SUPPORT" KERNEL_STAGE="$BASE" PATCH_DIR="$PATCH_DIR" \
  "$REPO_ROOT/scripts/stage-kernel-for-build.sh" >/dev/null 2>&1; then
  echo 'kernel stage unexpectedly accepted the baseline path' >&2
  exit 1
fi

mkdir "$TMP/bad"
cat > "$TMP/bad/10-incompatible.patch" <<'PATCH'
--- a/one/two/three/missing.txt
+++ b/one/two/three/missing.txt
@@ -1 +1 @@
-before
+after
PATCH
if KERNEL_BASE="$BASE" KERNEL_SUPPORT="$SUPPORT" KERNEL_STAGE="$TMP/bad-stage" PATCH_DIR="$TMP/bad" \
  "$REPO_ROOT/scripts/stage-kernel-for-build.sh" >/dev/null 2>&1; then
  echo 'incompatible kernel patch unexpectedly applied' >&2
  exit 1
fi
[[ "$(<"$BASE/marker.txt")" == before ]]

echo 'PASS kernel base stays immutable and bad patches are rejected'
