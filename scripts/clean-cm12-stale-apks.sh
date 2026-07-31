#!/usr/bin/env bash
# Remove stale APK outputs for headless packages filtered from Biscuit PRODUCT_PACKAGES.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM12="${CM12:-$REPO_ROOT/workspace/cm12}"

apps=(
  BasicDreams
  Browser
  Calculator
  Calendar
  Camera2
  CMFileManager
  CMWallpapers
  DeskClock
  Development
  Email
  Exchange2
  Gallery2
  LockClock
  PrintSpooler
  Terminal
)

priv_apps=(
  CMUpdater
  CyanogenSetupWizard
  ThemeChooser
  Trebuchet
  WallpaperCropper
)

clean_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    rm -rf "$path"
    echo "removed ${path#$REPO_ROOT/}"
  fi
}

for out in "$CM12"/out "$CM12"/out-*; do
  [[ -d "$out/target/product" ]] || continue

  for product in "$out"/target/product/*; do
    [[ -d "$product" ]] || continue

    for app in "${apps[@]}"; do
      clean_path "$product/system/app/$app"
    done

    for app in "${priv_apps[@]}"; do
      clean_path "$product/system/priv-app/$app"
    done
  done

  obj="$out/target/common/obj/APPS"
  [[ -d "$obj" ]] || continue

  for app in "${apps[@]}" "${priv_apps[@]}"; do
    clean_path "$obj/${app}_intermediates"
  done
done
