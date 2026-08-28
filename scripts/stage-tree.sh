#!/usr/bin/env bash
# Stage our vendored Biscuit sources into the ignored CM12 checkout.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM12="${CM12:-$REPO_ROOT/workspace/cm12}"

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

copy_files_from_dir() {
  local src="$1" dst="$2" label="$3"
  [[ -d "$src" ]] || { echo "SKIP $label: missing $src"; return 0; }
  mkdir -p "$dst"
  find "$dst" -maxdepth 1 -type f -delete
  find "$src" -maxdepth 1 -type f -name '*.[0-9]' -exec cp -a {} "$dst"/ \;
  echo "STAGED $label -> ${dst#$REPO_ROOT/}"
}

copy_file() {
  local src="$1" dst="$2" label="$3"
  [[ -f "$src" ]] || { echo "SKIP $label: missing $src"; return 0; }
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  echo "STAGED $label -> ${dst#$REPO_ROOT/}"
}

copy_dir "$REPO_ROOT/device/amazon/biscuit" \
         "$CM12/device/amazon/biscuit" \
         "device/amazon/biscuit"
copy_dir "$REPO_ROOT/device/amazon/mt8163-common" \
         "$CM12/device/amazon/mt8163-common" \
         "device/amazon/mt8163-common"
copy_dir "$REPO_ROOT/hardware/amazon" \
         "$CM12/hardware/amazon" \
         "hardware/amazon"
copy_dir "$REPO_ROOT/hardware/mediatek" \
         "$CM12/hardware/mediatek" \
         "hardware/mediatek"
copy_dir "$REPO_ROOT/workspace/vendor/amazon" \
         "$CM12/vendor/amazon" \
         "vendor/amazon"
"$REPO_ROOT/scripts/disable-mtk-omx-codecs.sh"
copy_files_from_dir "$REPO_ROOT/workspace/cacerts" \
                    "$CM12/libcore/luni/src/main/files/cacerts" \
                    "libcore cacerts"
copy_file "$REPO_ROOT/workspace/cacerts.pem" \
          "$CM12/device/amazon/biscuit/cacerts.pem" \
          "curl cacerts.pem"
copy_file "$REPO_ROOT/workspace/device/amazon/biscuit/prebuilt/kernel" \
          "$CM12/device/amazon/biscuit/prebuilt/kernel" \
          "prebuilt kernel"
copy_file "$REPO_ROOT/workspace/device/amazon/biscuit/prebuilt/kernel.sha256" \
          "$CM12/device/amazon/biscuit/prebuilt/kernel.sha256" \
          "prebuilt kernel checksum"
copy_file "$REPO_ROOT/workspace/device/amazon/biscuit/prebuilt/kernel-selection.txt" \
          "$CM12/device/amazon/biscuit/prebuilt/kernel-selection.txt" \
          "prebuilt kernel selection"
