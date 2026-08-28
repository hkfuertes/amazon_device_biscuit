#!/usr/bin/env bash
# Apply tracked vendor patches to an extracted proprietary tree.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH_DIR="${PATCH_DIR:-$REPO_ROOT/patches/vendor}"

[[ $# -eq 1 ]] || { echo "Usage: $0 <proprietary-tree>" >&2; exit 2; }
VENDOR_TREE="$1"
[[ -d "$VENDOR_TREE" ]] || { echo "ERROR: vendor tree missing at $VENDOR_TREE" >&2; exit 1; }
[[ -d "$PATCH_DIR" ]] || { echo "ERROR: vendor patch series missing at $PATCH_DIR" >&2; exit 1; }

while IFS= read -r -d '' patch_file; do
  rel="${patch_file#$REPO_ROOT/}"
  [[ "$rel" != "$patch_file" ]] || rel="$(basename "$patch_file")"
  if patch -d "$VENDOR_TREE" -p1 --forward --batch --dry-run --silent < "$patch_file" >/dev/null 2>&1; then
    patch -d "$VENDOR_TREE" -p1 --forward --batch --silent < "$patch_file"
    echo "APPLIED $rel"
  elif patch -d "$VENDOR_TREE" -p1 -R --forward --batch --dry-run --silent < "$patch_file" >/dev/null 2>&1; then
    echo "SKIP already applied $rel"
  else
    echo "ERROR: vendor patch does not apply cleanly: $rel" >&2
    patch -d "$VENDOR_TREE" -p1 --forward --batch --dry-run < "$patch_file"
    exit 1
  fi
done < <(LC_ALL=C find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' -print0 | LC_ALL=C sort -z)
