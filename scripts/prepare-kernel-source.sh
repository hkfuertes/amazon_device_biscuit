#!/usr/bin/env bash
# Download + stage Amazon Echo Dot 5.5.5.4 kernel source into ignored workspace/.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOWNLOADS="$REPO_ROOT/workspace/downloads"
UPSTREAM="$REPO_ROOT/workspace/upstream/amazon-echo-dot-5.5.5.4"
KERNEL_SOURCE="$REPO_ROOT/workspace/kernel/amazon/biscuit"
AMAZON_SOURCE_URL="${AMAZON_SOURCE_URL:-https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/Echo_Dot_src-5.5.5.4-20220824.tar.bz2}"
AMAZON_SOURCE_SHA256="${AMAZON_SOURCE_SHA256:-dd92a7ddd7c0fb9b61455542b84132ad00a445c38ef4f910b1272ac04f6f83dd}"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

mkdir -p "$DOWNLOADS" "$UPSTREAM" "$(dirname "$KERNEL_SOURCE")"
TARBALL="$DOWNLOADS/$(basename "$AMAZON_SOURCE_URL")"

if [[ ! -f "$TARBALL" ]]; then
  echo "Downloading $AMAZON_SOURCE_URL ..."
  curl -L --fail --progress-bar -o "$TARBALL" "$AMAZON_SOURCE_URL"
fi

echo "$AMAZON_SOURCE_SHA256  $TARBALL" | sha256sum -c -

if [[ -f "$KERNEL_SOURCE/Makefile" && "$FORCE" -eq 0 ]]; then
  echo "Kernel source already present: $KERNEL_SOURCE"
  echo "Use --force to re-stage."
  exit 0
fi

rm -rf "$UPSTREAM" "$KERNEL_SOURCE"
mkdir -p "$UPSTREAM" "$KERNEL_SOURCE"

echo "Extracting Amazon source tarball ..."
tar -xjf "$TARBALL" -C "$UPSTREAM"

echo "Staging kernel source ..."
tar -xf "$UPSTREAM/platform.tar" -C "$KERNEL_SOURCE" \
  --strip-components=4 \
  'kernel/mediatek/mt8163/3.18'

mkdir -p "$KERNEL_SOURCE/amazon-build"
tar -xzf "$UPSTREAM/build_kernel.tar.gz" -C "$KERNEL_SOURCE/amazon-build"

cat > "$KERNEL_SOURCE/README.md" <<EOF
# Amazon Biscuit kernel source

Source: Amazon Echo Dot 5.5.5.4 source release
URL: $AMAZON_SOURCE_URL
SHA256: $AMAZON_SOURCE_SHA256
Original tar path: \`platform.tar:kernel/mediatek/mt8163/3.18/\`
Defconfig: \`biscuit_defconfig\`
Arch: \`arm64\`

\`amazon-build/\` contains Amazon's original \`build_kernel.sh\`, config, and prebuilt headers from \`build_kernel.tar.gz\`.
EOF

echo "Kernel source ready: $KERNEL_SOURCE"
