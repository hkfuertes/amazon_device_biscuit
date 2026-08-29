#!/usr/bin/env bash
# Verify vendor patches are ordered, repeatable, and reject a changed stock format.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PROP="$TMP/proprietary"
mkdir -p "$PROP/etc" "$PROP/lib/egl"
cat > "$PROP/etc/audio_init.sh" <<'EOF'
# stock audio init
one
two
three
four
five
A_PGA_L="40"
A_PGA_R="40"
A_PGA_R_LINEIN="46"
EOF
printf '0 1 mali\n' > "$PROP/lib/egl/egl.cfg"

"$REPO_ROOT/scripts/apply-vendor-patches.sh" "$PROP" > "$TMP/first.log"
grep -qx 'A_PGA_L="70"' "$PROP/etc/audio_init.sh"
grep -qx 'A_PGA_R="70"' "$PROP/etc/audio_init.sh"
grep -qx 'A_PGA_R_LINEIN="46"' "$PROP/etc/audio_init.sh"
grep -qx '0 0 android' "$PROP/lib/egl/egl.cfg"
"$REPO_ROOT/scripts/apply-vendor-patches.sh" "$PROP" > "$TMP/repeat.log"
grep -q 'SKIP already applied patches/vendor/10-force-software-egl.patch' "$TMP/repeat.log"
grep -q 'SKIP already applied patches/vendor/20-microphone-pga-70.patch' "$TMP/repeat.log"

mkdir -p "$TMP/bad/etc" "$TMP/bad-patches"
printf 'A_PGA_L="41"\nA_PGA_R="40"\n' > "$TMP/bad/etc/audio_init.sh"
cp "$REPO_ROOT/patches/vendor/20-microphone-pga-70.patch" "$TMP/bad-patches/"
if PATCH_DIR="$TMP/bad-patches" "$REPO_ROOT/scripts/apply-vendor-patches.sh" "$TMP/bad" > "$TMP/bad.log" 2>&1; then
  echo 'changed stock audio format unexpectedly accepted' >&2
  exit 1
fi
grep -q 'ERROR: vendor patch does not apply cleanly: 20-microphone-pga-70.patch' "$TMP/bad.log"

echo 'PASS vendor patches preserve PGA policy and reject baseline drift'
