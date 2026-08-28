#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CM12="$TMP/cm12"
PATCH_DIR="$TMP/patches"
PROJECT="$CM12/frameworks/base"
CA_PROJECT="$CM12/libcore/luni"

mkdir -p "$CM12/.repo" "$PROJECT" "$CA_PROJECT/src/main/files/cacerts" "$PATCH_DIR"
git init -q "$PROJECT"
git -C "$PROJECT" config user.email test@example.invalid
git -C "$PROJECT" config user.name test
printf 'base\n' > "$PROJECT/covered.txt"
printf 'base\n' > "$PROJECT/metadata-only"
printf 'base\n' > "$PROJECT/uncovered.txt"
git -C "$PROJECT" add .
git -C "$PROJECT" commit -qm base
printf 'changed\n' > "$PROJECT/covered.txt"
printf 'changed\n' > "$PROJECT/metadata-only"

git init -q "$CA_PROJECT"
git -C "$CA_PROJECT" config user.email test@example.invalid
git -C "$CA_PROJECT" config user.name test
printf 'base\n' > "$CA_PROJECT/src/main/files/cacerts/test.0"
git -C "$CA_PROJECT" add .
git -C "$CA_PROJECT" commit -qm base
printf 'materialized\n' > "$CA_PROJECT/src/main/files/cacerts/test.0"

cat > "$PATCH_DIR/10-covered.patch" <<'PATCH'
--- a/frameworks/base/covered.txt
+++ b/frameworks/base/covered.txt
@@ -1 +1 @@
-base
+changed
PATCH
cat > "$PATCH_DIR/20-metadata-only.patch" <<'PATCH'
diff --git a/frameworks/base/metadata-only b/frameworks/base/metadata-only
similarity index 100%
rename from frameworks/base/metadata-only
rename to frameworks/base/metadata-only
PATCH

CM12="$CM12" PATCH_DIR="$PATCH_DIR" CM12_DIFF_JOBS=2 \
  "$REPO_ROOT/scripts/cm12-diff-upstream.sh" > "$TMP/covered.out"
grep -Fqx 'frameworks/base/covered.txt' "$TMP/covered.out"
grep -Fqx 'frameworks/base/metadata-only' "$TMP/covered.out"
grep -Fqx 'libcore/luni/src/main/files/cacerts/test.0' "$TMP/covered.out"
grep -A1 -- '-- Dirty files missing from patches --' "$TMP/covered.out" | grep -Fqx 'none'

printf 'changed\n' > "$PROJECT/uncovered.txt"
if CM12="$CM12" PATCH_DIR="$PATCH_DIR" CM12_DIFF_JOBS=2 \
  "$REPO_ROOT/scripts/cm12-diff-upstream.sh" > "$TMP/uncovered.out" 2>&1; then
  echo 'ERROR: uncovered delta was accepted' >&2
  exit 1
fi
grep -Fqx 'frameworks/base/uncovered.txt' "$TMP/uncovered.out"

echo 'cm12 delta audit fixture passed.'
