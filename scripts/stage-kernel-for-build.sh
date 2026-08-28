#!/usr/bin/env bash
# Copy the verified Amazon kernel baseline and apply only the kernel patch series.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_BASE="${KERNEL_BASE:-$REPO_ROOT/workspace/kernel/amazon/biscuit}"
KERNEL_SUPPORT="${KERNEL_SUPPORT:-$REPO_ROOT/workspace/kernel/amazon/biscuit-build-support}"
KERNEL_STAGE="${KERNEL_STAGE:-$REPO_ROOT/workspace/kernel/build/biscuit}"
PATCH_DIR="${PATCH_DIR:-$REPO_ROOT/patches/kernel}"

[[ -f "$KERNEL_BASE/Makefile" ]] || { echo "ERROR: kernel base missing at $KERNEL_BASE" >&2; exit 1; }
[[ -f "$KERNEL_BASE/arch/arm64/configs/biscuit_defconfig" ]] || { echo "ERROR: Biscuit defconfig missing from $KERNEL_BASE" >&2; exit 1; }
[[ -d "$KERNEL_SUPPORT/prebuilt" ]] || { echo "ERROR: kernel build support missing at $KERNEL_SUPPORT" >&2; exit 1; }
[[ -d "$PATCH_DIR" ]] || { echo "ERROR: kernel patch series missing at $PATCH_DIR" >&2; exit 1; }
[[ "$KERNEL_STAGE" != "$KERNEL_BASE" && "$KERNEL_STAGE" != "$KERNEL_SUPPORT" ]] || {
  echo "ERROR: kernel stage must differ from the immutable inputs" >&2
  exit 1
}

rm -rf "$KERNEL_STAGE"
mkdir -p "$KERNEL_STAGE/amazon-build"
cp -a "$KERNEL_BASE/." "$KERNEL_STAGE/"
cp -a "$KERNEL_SUPPORT/." "$KERNEL_STAGE/amazon-build/"

while IFS= read -r -d '' patch_file; do
  rel="${patch_file#$REPO_ROOT/}"
  [[ "$rel" != "$patch_file" ]] || rel="$(basename "$patch_file")"
  if patch -d "$KERNEL_STAGE" -p4 --forward --batch --dry-run --silent < "$patch_file" >/dev/null 2>&1; then
    patch -d "$KERNEL_STAGE" -p4 --forward --batch --silent < "$patch_file"
    echo "APPLIED $rel"
  else
    echo "ERROR: kernel patch does not apply cleanly: $rel" >&2
    patch -d "$KERNEL_STAGE" -p4 --forward --batch --dry-run < "$patch_file"
    exit 1
  fi
done < <(LC_ALL=C find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' -print0 | LC_ALL=C sort -z)

echo "Kernel build stage ready: $KERNEL_STAGE"
