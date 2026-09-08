#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT="$ROOT/device/amazon/biscuit/biscuit_bootstrap.mk"
DEVICE="$ROOT/device/amazon/biscuit/biscuit_bootstrap_device.mk"
INIT="$ROOT/device/amazon/biscuit/rootdir/init.biscuit.bootstrap.rc"

for file in "$PRODUCT" "$DEVICE" "$INIT"; do
  [[ -f "$file" ]] || { echo "missing: $file" >&2; exit 1; }
done

! grep -Eq 'inherit-product.*(full_base|core_minimal|core_tiny|vendor/cm/config/common)' "$PRODUCT" "$DEVICE"
grep -Fq 'PRODUCT_NAME         := biscuit_bootstrap' "$PRODUCT"
grep -Fq 'ro.echolocal.install_mode=standalone' "$PRODUCT"
grep -Fq 'wpa_supplicant' "$DEVICE"
grep -Fq 'dhcpcd' "$DEVICE"
grep -Fq 'tinymix' "$DEVICE"
grep -Fq 'LIBART_IMG_HOST_BASE_ADDRESS := 0x60000000' "$DEVICE"
grep -Fq 'LIBART_IMG_TARGET_BASE_ADDRESS := 0x70000000' "$DEVICE"
grep -Fq 'WITH_DEXPREOPT := false' "$DEVICE"
grep -Fq 'service echod /system/app/echod/echod' "$INIT"
! grep -Fq 'service biscuit-ledd' "$INIT"

echo 'bootstrap product static checks passed'
