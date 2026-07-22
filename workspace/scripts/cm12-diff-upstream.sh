#!/usr/bin/env bash
# Show CM12 changes that must be represented by workspace/patches/*.patch.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CM12="$REPO_ROOT/workspace/cm12"
PATCH_DIR="$REPO_ROOT/workspace/patches"

[[ -d "$CM12/.repo" ]] || { echo "ERROR: CM12 repo checkout missing at $CM12" >&2; exit 1; }

tmp_changed="$(mktemp)"
tmp_patched="$(mktemp)"
trap 'rm -f "$tmp_changed" "$tmp_patched"' EXIT

find "$CM12" \
  -path "$CM12/.repo" -prune -o \
  -path "$CM12/out-docker" -prune -o \
  -name .git -print |
while read -r gitref; do
  project="${gitref%/.git}"
  rel_project="${project#$CM12/}"
  git -C "$project" diff --name-only HEAD | sed "s#^#$rel_project/#"
done | sort -u > "$tmp_changed"

for p in "$PATCH_DIR"/*.patch; do
  [[ -e "$p" ]] || continue
  grep -E '^\+\+\+ b/' "$p" | sed 's#^+++ b/##; s#\t.*##'
done | sort -u > "$tmp_patched"

echo "-- CM12 dirty files vs upstream HEAD --"
if [[ -s "$tmp_changed" ]]; then
  cat "$tmp_changed"
else
  echo "none"
fi

echo ""
echo "-- Dirty files missing from patches --"
missing="$(comm -23 "$tmp_changed" "$tmp_patched")"
if [[ -n "$missing" ]]; then
  echo "$missing"
  exit 1
else
  echo "none"
fi

echo ""
echo "-- Patch paths with no dirty counterpart (ok for staged vendor files or unapplied patches) --"
comm -13 "$tmp_changed" "$tmp_patched" || true
