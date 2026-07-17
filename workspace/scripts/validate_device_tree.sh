#!/usr/bin/env bash
# validate_device_tree.sh — static validation for the Biscuit CM12 device tree.
# Does NOT require a CM12 source checkout or Docker.
# Exits non-zero if any required file/pattern is missing.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TREE="$REPO_ROOT/workspace/device/amazon/biscuit"

PASS=0
FAIL=0

check() {
  local desc="$1"; local cond="$2"
  if eval "$cond" >/dev/null 2>&1; then
    echo "  OK   $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Biscuit device tree static validation ==="
echo "Tree: $TREE"
echo ""

# ── Required files ───────────────────────────────────────────────────────────
echo "-- Required files --"
check "AndroidProducts.mk exists"   "[[ -f '$TREE/AndroidProducts.mk' ]]"
check "cm_biscuit.mk exists"        "[[ -f '$TREE/cm_biscuit.mk' ]]"
check "device.mk exists"            "[[ -f '$TREE/device.mk' ]]"
check "BoardConfig.mk exists"       "[[ -f '$TREE/BoardConfig.mk' ]]"
check "fstab.mt8163 exists"         "[[ -f '$TREE/recovery/root/etc/fstab.mt8163' ]]"
check "DECISIONS.md exists"         "[[ -f '$TREE/DECISIONS.md' ]]"

echo ""
echo "-- AndroidProducts.mk content --"
check "PRODUCT_MAKEFILES references cm_biscuit.mk" \
  "grep -q 'cm_biscuit.mk' '$TREE/AndroidProducts.mk'"

echo ""
echo "-- cm_biscuit.mk content --"
check "PRODUCT_NAME := cm_biscuit" \
  "grep -q 'PRODUCT_NAME.*cm_biscuit' '$TREE/cm_biscuit.mk'"
check "PRODUCT_DEVICE := biscuit" \
  "grep -q 'PRODUCT_DEVICE.*biscuit' '$TREE/cm_biscuit.mk'"
check "includes device.mk" \
  "grep -q 'device/amazon/biscuit/device.mk' '$TREE/cm_biscuit.mk'"

echo ""
echo "-- BoardConfig.mk content --"
check "TARGET_ARCH := arm64" \
  "grep -q 'TARGET_ARCH.*arm64' '$TREE/BoardConfig.mk'"
check "TARGET_BOARD_PLATFORM := mt8163" \
  "grep -q 'TARGET_BOARD_PLATFORM.*mt8163' '$TREE/BoardConfig.mk'"
check "BOARD_KERNEL_BASE present" \
  "grep -q 'BOARD_KERNEL_BASE' '$TREE/BoardConfig.mk'"
check "BOARD_SYSTEMIMAGE_PARTITION_SIZE present" \
  "grep -q 'BOARD_SYSTEMIMAGE_PARTITION_SIZE' '$TREE/BoardConfig.mk'"
check "Partition size comment references gpt-biscuit.bin" \
  "grep -q 'gpt-biscuit.bin' '$TREE/BoardConfig.mk'"

echo ""
echo "-- Symlink check (if CM12 synced) --"
SYMLINK="$REPO_ROOT/workspace/cm12/device/amazon/biscuit"
if [[ -d "$REPO_ROOT/workspace/cm12/build" ]]; then
  check "device tree symlink in cm12/" "[[ -L '$SYMLINK' ]]"
else
  echo "  SKIP cm12/ not synced — run preflight.sh after repo sync"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
