#!/usr/bin/env bash
# Cheap checks only. No downloads, no sync, no build, no flashing.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

check_file() { [[ -f "$1" ]] && echo "OK $2" || { echo "MISS $2: $1"; fail=1; }; }
check_dir() { [[ -d "$1" ]] && echo "OK $2" || { echo "MISS $2: $1"; fail=1; }; }
check_cmd() { command -v "$1" >/dev/null 2>&1 && echo "OK cmd $1" || { echo "MISS cmd $1"; fail=1; }; }

ca_bundle_matches_pin() {
  local dir="$REPO_ROOT/workspace/cacerts" bundle="$REPO_ROOT/workspace/cacerts.pem"
  local metadata="$REPO_ROOT/workspace/cacerts.source" expected actual count
  [[ -n "${AOSP_CA_REVISION:-}" && -d "$dir" && -f "$bundle" && -f "$metadata" ]] || return 1
  grep -Fqx "source_revision=$AOSP_CA_REVISION" "$metadata" || return 1
  expected="$(awk -F= '$1 == "bundle_sha256" { print $2 }' "$metadata")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || return 1
  actual="$(sha256sum "$bundle" | awk '{ print $1 }')"
  [[ "$actual" == "$expected" ]] || return 1
  count="$(awk -F= '$1 == "certificate_count" { print $2 }' "$metadata")"
  [[ "$count" =~ ^[1-9][0-9]*$ ]] || return 1
  [[ "$(find "$dir" -maxdepth 1 -type f -name '*.[0-9]' -printf . | wc -c)" -eq "$count" ]]
}

CA_CONFIG="$REPO_ROOT/config/ca-certificates.env"
check_file "$CA_CONFIG" "pinned AOSP CA input"
if [[ -f "$CA_CONFIG" ]]; then
  # shellcheck source=../config/ca-certificates.env
  source "$CA_CONFIG"
  if [[ "${AOSP_CA_REVISION:-}" =~ ^[0-9a-f]{40}$ ]]; then
    echo "OK pinned AOSP CA revision $AOSP_CA_REVISION"
  else
    echo "MISS immutable AOSP CA revision in $CA_CONFIG"
    fail=1
  fi
fi

check_file "$REPO_ROOT/manifest/cm12.lock.xml" "CM12 locked manifest"
check_dir "$REPO_ROOT/device/amazon/biscuit" "Biscuit device source"
check_dir "$REPO_ROOT/device/amazon/mt8163-common" "MT8163 common source"
check_dir "$REPO_ROOT/hardware/amazon" "Amazon hardware source"
check_dir "$REPO_ROOT/hardware/mediatek" "Mediatek hardware source"
check_dir "$REPO_ROOT/patches" "patches"
check_dir "$REPO_ROOT/docker" "dockerfiles"

check_cmd git
check_cmd curl
check_cmd sha256sum
check_cmd tar
check_cmd docker
check_cmd 7z

if [[ -d "$REPO_ROOT/workspace/cm12/build" ]]; then
  echo "OK workspace/cm12 synced"
else
  echo "MISS workspace/cm12/build; run scripts/sync-cm12.sh or scripts/bootstrap-workspace.sh"
  fail=1
fi

if [[ -f "$REPO_ROOT/workspace/kernel/amazon/biscuit/arch/arm64/configs/biscuit_defconfig" ]]; then
  echo "OK kernel source staged"
else
  echo "MISS kernel source; run scripts/prepare-kernel-source.sh"
  fail=1
fi

if [[ -f "$REPO_ROOT/workspace/extracted/biscuit-stock-272.6.4.1/system.img" ]]; then
  echo "OK stock Biscuit system.img prepared"
else
  echo "MISS stock Biscuit system.img; run scripts/prepare-biscuit-stock-system-image.sh"
  fail=1
fi

if [[ -f "$REPO_ROOT/workspace/vendor/amazon/mt8163-common/mt8163-common-vendor.mk" && -f "$REPO_ROOT/workspace/vendor/amazon/mt8163-common/BoardConfigVendor.mk" && -f "$REPO_ROOT/workspace/vendor/amazon/biscuit/biscuit-vendor.mk" ]]; then
  echo "OK stock Biscuit blobs extracted"
else
  echo "MISS stock Biscuit blobs; run scripts/extract-biscuit-stock-blobs.sh <system.img>"
  fail=1
fi

if [[ -f "$REPO_ROOT/workspace/device/amazon/biscuit/prebuilt/kernel" ]]; then
  echo "OK prebuilt kernel present"
else
  echo "MISS prebuilt kernel; run scripts/build-kernel.sh"
  fail=1
fi

if ca_bundle_matches_pin; then
  echo "OK pinned AOSP CA bundle materialized"
else
  echo "MISS pinned AOSP CA bundle; run scripts/update-ca-certs.sh"
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "Preflight failed."
  exit 1
fi

echo "Preflight OK."
