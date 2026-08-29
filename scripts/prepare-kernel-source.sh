#!/usr/bin/env bash
# Download and materialize a verified, unmodified Amazon Biscuit kernel baseline.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOWNLOADS="$REPO_ROOT/workspace/downloads"
UPSTREAM="$REPO_ROOT/workspace/upstream/amazon-echo-dot-5.5.5.4"
KERNEL_BASE="$REPO_ROOT/workspace/kernel/amazon/biscuit"
KERNEL_SUPPORT="$REPO_ROOT/workspace/kernel/amazon/biscuit-build-support"
KERNEL_METADATA="$REPO_ROOT/workspace/kernel/amazon/biscuit-source.md"
AMAZON_SOURCE_URL="${AMAZON_SOURCE_URL:-https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/Echo_Dot_src-5.5.5.4-20220824.tar.bz2}"
AMAZON_SOURCE_SHA256="${AMAZON_SOURCE_SHA256:-dd92a7ddd7c0fb9b61455542b84132ad00a445c38ef4f910b1272ac04f6f83dd}"
FORCE=0
case "${1:-}" in
  '') ;;
  --force) FORCE=1 ;;
  *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
esac

mkdir -p "$DOWNLOADS" "$(dirname "$UPSTREAM")" "$(dirname "$KERNEL_BASE")"
TARBALL="$DOWNLOADS/$(basename "$AMAZON_SOURCE_URL")"

if [[ ! -f "$TARBALL" ]]; then
  echo "Downloading $AMAZON_SOURCE_URL ..."
  curl -L --fail --progress-bar -o "$TARBALL" "$AMAZON_SOURCE_URL"
fi

echo "$AMAZON_SOURCE_SHA256  $TARBALL" | sha256sum -c -

if [[ -f "$KERNEL_BASE/Makefile" && \
      -f "$KERNEL_BASE/arch/arm64/configs/biscuit_defconfig" && \
      -d "$KERNEL_SUPPORT/prebuilt" && \
      -f "$KERNEL_METADATA" && "$FORCE" -eq 0 ]]; then
  echo "Kernel base already materialized: $KERNEL_BASE"
  exit 0
fi

rm -rf "$UPSTREAM" "$KERNEL_BASE" "$KERNEL_SUPPORT" "$KERNEL_METADATA"
mkdir -p "$UPSTREAM" "$KERNEL_BASE" "$KERNEL_SUPPORT"

echo "Extracting Amazon source tarball ..."
tar -xjf "$TARBALL" -C "$UPSTREAM"
[[ -f "$UPSTREAM/platform.tar" && -f "$UPSTREAM/build_kernel.tar.gz" ]] || {
  echo "ERROR: Amazon source release is missing platform.tar or build_kernel.tar.gz" >&2
  exit 1
}

echo "Materializing unmodified kernel base ..."
tar -xf "$UPSTREAM/platform.tar" -C "$KERNEL_BASE" \
  --strip-components=4 \
  'kernel/mediatek/mt8163/3.18'
tar -xzf "$UPSTREAM/build_kernel.tar.gz" -C "$KERNEL_SUPPORT"

[[ -f "$KERNEL_BASE/Makefile" && \
   -f "$KERNEL_BASE/arch/arm64/configs/biscuit_defconfig" && \
   -d "$KERNEL_SUPPORT/prebuilt" ]] || {
  echo "ERROR: extracted Amazon kernel baseline is incomplete" >&2
  exit 1
}

cat > "$KERNEL_METADATA" <<EOF
# Amazon Biscuit kernel source

Source: Amazon Echo Dot 5.5.5.4 source release
URL: $AMAZON_SOURCE_URL
SHA256: $AMAZON_SOURCE_SHA256
Base: workspace/kernel/amazon/biscuit
Build support: workspace/kernel/amazon/biscuit-build-support
Original tar path: \`platform.tar:kernel/mediatek/mt8163/3.18/\`
Defconfig: \`biscuit_defconfig\`
Arch: \`arm64\`
EOF

echo "Kernel base ready: $KERNEL_BASE"
echo "Kernel build support ready: $KERNEL_SUPPORT"
