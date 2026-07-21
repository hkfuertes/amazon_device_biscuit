#!/usr/bin/env bash
# Stage our vendored Biscuit sources into the ignored CM12 checkout.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CM12="$REPO_ROOT/workspace/cm12"

[[ -d "$CM12/build" ]] || { echo "ERROR: CM12 not synced at $CM12" >&2; exit 1; }

copy_dir() {
  local src="$1" dst="$2" label="$3"
  [[ -d "$src" ]] || { echo "SKIP $label: missing $src"; return 0; }
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  find "$dst" \( -name .git -o -name .repo \) -prune -exec rm -rf {} +
  echo "STAGED $label -> ${dst#$REPO_ROOT/}"
}

copy_dir "$REPO_ROOT/workspace/device/amazon/biscuit" \
         "$CM12/device/amazon/biscuit" \
         "device/amazon/biscuit"
copy_dir "$REPO_ROOT/workspace/device/amazon/mt8163-common" \
         "$CM12/device/amazon/mt8163-common" \
         "device/amazon/mt8163-common"
copy_dir "$REPO_ROOT/workspace/hardware/amazon" \
         "$CM12/hardware/amazon" \
         "hardware/amazon"
copy_dir "$REPO_ROOT/workspace/hardware/mediatek" \
         "$CM12/hardware/mediatek" \
         "hardware/mediatek"
copy_dir "$REPO_ROOT/workspace/vendor/amazon" \
         "$CM12/vendor/amazon" \
         "vendor/amazon"
