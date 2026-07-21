#!/usr/bin/env bash
# Apply tracked CM12 patches. Safe to re-run: skips already-applied patches.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CM12="$REPO_ROOT/workspace/cm12"

[[ -d "$CM12/build" ]] || { echo "ERROR: CM12 not synced at $CM12" >&2; exit 1; }

for patch in "$REPO_ROOT"/workspace/patches/*.patch; do
  [[ -e "$patch" ]] || continue
  rel="${patch#$REPO_ROOT/}"
  if patch -d "$CM12" -p1 --forward --batch --dry-run --silent < "$patch"; then
    patch -d "$CM12" -p1 --forward --batch --silent < "$patch"
    echo "APPLIED $rel"
  elif patch -d "$CM12" -p1 -R --forward --batch --dry-run --silent < "$patch"; then
    echo "SKIP already applied $rel"
  else
    echo "ERROR: patch does not apply cleanly: $rel" >&2
    patch -d "$CM12" -p1 --forward --batch --dry-run < "$patch"
    exit 1
  fi
done
