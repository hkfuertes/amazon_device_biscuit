#!/usr/bin/env bash
# Verify directory-scoped patches apply in sorted order and skip unchanged state.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/root" "$TMP/patches"
printf 'one\n' >"$TMP/root/file.txt"
cat >"$TMP/patches/010-first.patch" <<'PATCH'
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-one
+two
PATCH
cat >"$TMP/patches/020-second.patch" <<'PATCH'
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-two
+three
PATCH

PATCH_REAPPLY=1 PATCH_STATE_DIR="$TMP/state" \
  "$ROOT/scripts/apply-patches.sh" "$TMP/root" 1 "$TMP/patches" >"$TMP/first.log"
printf 'three\n' | diff -u - "$TMP/root/file.txt"
sed -n '1p;2p' "$TMP/first.log" | diff -u - <(printf 'APPLIED %s/patches/010-first.patch\nAPPLIED %s/patches/020-second.patch\n' "$TMP" "$TMP")

PATCH_REAPPLY=1 PATCH_STATE_DIR="$TMP/state" \
  "$ROOT/scripts/apply-patches.sh" "$TMP/root" 1 "$TMP/patches" >"$TMP/repeat.log"
grep -qx "SKIP patch directory unchanged $TMP/patches" "$TMP/repeat.log"

mkdir -p "$TMP/bad"
cat >"$TMP/bad/010-bad.patch" <<'PATCH'
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-missing
+nope
PATCH
if "$ROOT/scripts/apply-patches.sh" "$TMP/root" 1 "$TMP/bad" >"$TMP/bad.log" 2>&1; then
  echo 'incompatible patch unexpectedly applied' >&2
  exit 1
fi
grep -q 'ERROR: patch does not apply cleanly:' "$TMP/bad.log"

echo 'PASS directory patch application'
