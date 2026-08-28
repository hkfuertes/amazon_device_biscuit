#!/usr/bin/env bash
# build-kernel.sh — Build the Biscuit kernel from the Amazon Echo Dot 5.5.5.4 source.
#
# Prerequisites:
#   1. Docker image biscuit-kernel-builder:latest must exist.
#      Build it once with:
#        docker build -f docker/biscuit-kernel-builder.Dockerfile \
#                     -t biscuit-kernel-builder:latest \
#                     docker/
#
# Output:
#   workspace/device/amazon/biscuit/prebuilt/kernel
#     — arm64 Image suitable for mkbootimg; also arch/arm64/boot/Image.gz-dtb if dtb present
#
# Usage:
#   scripts/build-kernel.sh [--rebuild-image] [--jobs N]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SOURCE="$REPO_ROOT/workspace/kernel/amazon/biscuit"
KERNEL_PATCH_DIR="$REPO_ROOT/patches/kernel"
PREBUILT_DIR="$REPO_ROOT/workspace/device/amazon/biscuit/prebuilt"
CM12_PREBUILT_DIR="$REPO_ROOT/workspace/cm12/device/amazon/biscuit/prebuilt"
KERNEL_OUT="${KERNEL_OUT:-$REPO_ROOT/workspace/kernel-out}"
DOCKER_IMAGE="biscuit-kernel-builder:latest"
CONTAINER="biscuit-kernel-build"
JOBS="${JOBS:-$(nproc)}"
CLEAN_KERNEL_OUT="${CLEAN_KERNEL_OUT:-0}"

REBUILD_IMAGE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebuild-image) REBUILD_IMAGE=1; shift ;;
    --jobs) JOBS="$2"; shift 2 ;;
    -h|--help)
      sed -n '1,18p' "$0"
      exit 0
      ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── 1. Ensure kernel source exists ─────────────────────────────────────────
if [[ ! -f "$KERNEL_SOURCE/Makefile" || ! -f "$KERNEL_SOURCE/arch/arm64/configs/biscuit_defconfig" ]]; then
  "$REPO_ROOT/scripts/prepare-kernel-source.sh"
fi

# ── 2. Validate the kernel patch series ──────────────────────────────────────
[[ -d "$KERNEL_PATCH_DIR" ]] || { echo "ERROR: kernel patch series missing at $KERNEL_PATCH_DIR" >&2; exit 1; }

# ── 3. Ensure Docker image exists ────────────────────────────────────────────
if [[ "$REBUILD_IMAGE" -eq 1 ]] || ! docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
  echo "Building $DOCKER_IMAGE ..."
  docker build \
    -f "$REPO_ROOT/docker/biscuit-kernel-builder.Dockerfile" \
    -t "$DOCKER_IMAGE" \
    "$REPO_ROOT/docker/"
fi

# ── 4. Prepare output directory ──────────────────────────────────────────────
if [[ "$CLEAN_KERNEL_OUT" == 1 && -d "$KERNEL_OUT" ]]; then
  echo "Removing stale kernel-out/ ..."
  rm -rf "$KERNEL_OUT"
fi
mkdir -p "$KERNEL_OUT"

# ── 5. Run kernel build inside Docker ────────────────────────────────────────
# Mount:
#   /kernel-src — read-only vendored Amazon kernel source
#   /patches — read-only kernel patch series
#   /kernel-out — writable output directory

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Removing stale container '$CONTAINER'..."
  docker rm -f "$CONTAINER" >/dev/null
fi

echo "Starting kernel build in container '$CONTAINER' (jobs=$JOBS) ..."
docker run \
  --name "$CONTAINER" \
  --user "$(id -u):$(id -g)" \
  -v "$KERNEL_SOURCE:/kernel-src:ro" \
  -v "$KERNEL_PATCH_DIR:/patches:ro" \
  -v "$KERNEL_OUT:/kernel-out" \
  "$DOCKER_IMAGE" \
  bash -lc "
set -euo pipefail

TMPDIR=\$(mktemp -d)
trap 'rm -rf \$TMPDIR' EXIT

DEFCONFIG_NAME=\"biscuit_defconfig\"
TARGET_ARCH=\"arm64\"

SRC_DIR=\"\$TMPDIR/src\"
echo '==> Copying vendored kernel source ...'
mkdir -p \"\$SRC_DIR\"
cp -a /kernel-src/. \"\$SRC_DIR/\"

echo '==> Applying Biscuit kernel patches ...'
while IFS= read -r -d '' p; do
  echo '==> Applying' "\$p"
  patch -d "\$SRC_DIR" -p4 < "\$p"
done < <(LC_ALL=C find /patches -maxdepth 1 -type f -name '*.patch' -print0 | LC_ALL=C sort -z)

OUT_DIR=\"\$TMPDIR/out\"
mkdir -p \"\$OUT_DIR\"

TOOLCHAIN_PREFIX=\"/toolchain/aarch64-linux-android-4.9/bin/aarch64-linux-android-\"
MAKE_ARGS=\"-C \$SRC_DIR O=\$OUT_DIR ARCH=\$TARGET_ARCH CROSS_COMPILE=\$TOOLCHAIN_PREFIX\"

echo '==> make defconfig ...'
make \$MAKE_ARGS \$DEFCONFIG_NAME

# Apply trapz.config if present
TRAPZ=\"\$SRC_DIR/arch/\$TARGET_ARCH/configs/trapz.config\"
if [[ -f \"\$TRAPZ\" ]]; then
  echo '==> Appending trapz.config ...'
  cat \"\$TRAPZ\" >> \"\$OUT_DIR/.config\"
fi

echo '==> make oldconfig ...'
# ponytail: </dev/null avoids yes-pipe SIGPIPE + pipefail trap; accepts Kconfig defaults for new symbols
make \$MAKE_ARGS oldconfig </dev/null

echo '==> make headers_install ...'
make \$MAKE_ARGS headers_install

# Copy prebuilt headers from Amazon's build_kernel.tar.gz
if [[ -d \"\$SRC_DIR/amazon-build/prebuilt\" ]]; then
  echo '==> Copying Amazon prebuilt headers ...'
  cp -av \"\$SRC_DIR/amazon-build/prebuilt/\"* \"\$OUT_DIR/\"
fi

echo '==> make -j$JOBS ...'
make \$MAKE_ARGS -j$JOBS

# Copy kernel image(s) to output
echo '==> Copying boot artifacts to /kernel-out ...'
find \"\$OUT_DIR/arch/\$TARGET_ARCH/boot\" -type f | while read f; do
  rel=\"\${f#\$OUT_DIR/}\"
  dir=\"/kernel-out/\$(dirname \"\$rel\")\"
  mkdir -p \"\$dir\"
  cp -v \"\$f\" \"/kernel-out/\$rel\"
done

echo '==> Done.'
"

# ── 6. Copy kernel to prebuilt/ ──────────────────────────────────────────────
mkdir -p "$PREBUILT_DIR"

# Prefer Image.gz-dtb, fall back to Image, then Image.gz
KERNEL_IMAGE=""
for candidate in \
    "$KERNEL_OUT/arch/arm64/boot/Image.gz-dtb" \
    "$KERNEL_OUT/arch/arm64/boot/Image" \
    "$KERNEL_OUT/arch/arm64/boot/Image.gz"; do
  if [[ -f "$candidate" ]]; then
    KERNEL_IMAGE="$candidate"
    break
  fi
done

if [[ -z "$KERNEL_IMAGE" ]]; then
  echo "ERROR: No kernel image found in $KERNEL_OUT/arch/arm64/boot/"
  ls -la "$KERNEL_OUT/arch/arm64/boot/" 2>/dev/null || true
  exit 1
fi

cp "$KERNEL_IMAGE" "$PREBUILT_DIR/kernel"
mkdir -p "$CM12_PREBUILT_DIR"
cp "$KERNEL_IMAGE" "$CM12_PREBUILT_DIR/kernel"
sha256sum "$PREBUILT_DIR/kernel" | tee "$PREBUILT_DIR/kernel.sha256"
sha256sum "$CM12_PREBUILT_DIR/kernel" > "$CM12_PREBUILT_DIR/kernel.sha256"
cat > "$PREBUILT_DIR/kernel-selection.txt" <<EOF
source=workspace/kernel/amazon/biscuit
kernel=${KERNEL_IMAGE#$REPO_ROOT/}
upstream_url=https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/Echo_Dot_src-5.5.5.4-20220824.tar.bz2
upstream_sha256=dd92a7ddd7c0fb9b61455542b84132ad00a445c38ef4f910b1272ac04f6f83dd
container=$CONTAINER
log=docker logs $CONTAINER
reason=official Amazon Echo Dot 5.5.5.4 kernel source, biscuit_defconfig, CM12/netfilter fix, Image.gz-dtb
EOF
cp "$PREBUILT_DIR/kernel-selection.txt" "$CM12_PREBUILT_DIR/kernel-selection.txt"

echo ""
echo "Kernel build complete."
echo "  Image:   $KERNEL_IMAGE"
echo "  Prebuilt: $PREBUILT_DIR/kernel"
echo ""
echo "Logs: docker logs $CONTAINER"
echo "Next: run scripts/build-boot-img.sh once CM12 ramdisk is available."
