#!/usr/bin/env bash
# build-kernel.sh — Build the Biscuit kernel from the Amazon Echo Dot 5.5.5.4 source.
#
# Prerequisites:
#   1. workspace/scripts/preflight.sh must have run (upstream/ populated).
#   2. Docker image biscuit-kernel-builder:latest must exist.
#      Build it once with:
#        docker build -f workspace/docker/biscuit-kernel-builder.Dockerfile \
#                     -t biscuit-kernel-builder:latest \
#                     workspace/docker/
#
# Output:
#   workspace/device/amazon/biscuit/prebuilt/kernel
#     — arm64 Image suitable for mkbootimg; also arch/arm64/boot/Image.gz-dtb if dtb present
#
# Usage:
#   workspace/scripts/build-kernel.sh [--rebuild-image] [--jobs N]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UPSTREAM="$REPO_ROOT/workspace/upstream"
DOWNLOADS="$REPO_ROOT/workspace/downloads"
PREBUILT_DIR="$REPO_ROOT/workspace/device/amazon/biscuit/prebuilt"
CM12_PREBUILT_DIR="$REPO_ROOT/workspace/cm12/device/amazon/biscuit/prebuilt"
KERNEL_OUT="${KERNEL_OUT:-$REPO_ROOT/workspace/kernel-out}"
DOCKER_IMAGE="biscuit-kernel-builder:latest"
CONTAINER="biscuit-kernel-build"
JOBS="${JOBS:-$(nproc)}"

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

# ── 1. Guard: preflight must have run ───────────────────────────────────────
SENTINEL="$UPSTREAM/.extracted"
if [[ ! -f "$SENTINEL" ]]; then
  echo "ERROR: workspace/upstream/ not populated. Run workspace/scripts/preflight.sh first."
  exit 1
fi

PLATFORM_TAR="$UPSTREAM/platform.tar"
BUILD_KERNEL_TAR="$UPSTREAM/build_kernel.tar.gz"
for f in "$PLATFORM_TAR" "$BUILD_KERNEL_TAR"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Missing $f — re-run preflight.sh"
    exit 1
  fi
done

# ── 2. Ensure Docker image exists ────────────────────────────────────────────
if [[ "$REBUILD_IMAGE" -eq 1 ]] || ! docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
  echo "Building $DOCKER_IMAGE ..."
  docker build \
    -f "$REPO_ROOT/workspace/docker/biscuit-kernel-builder.Dockerfile" \
    -t "$DOCKER_IMAGE" \
    "$REPO_ROOT/workspace/docker/"
fi

# ── 3. Prepare output directory ──────────────────────────────────────────────
if [[ -d "$KERNEL_OUT" ]]; then
  echo "Removing stale kernel-out/ ..."
  rm -rf "$KERNEL_OUT"
fi
mkdir -p "$KERNEL_OUT"

# ── 4. Run kernel build inside Docker ────────────────────────────────────────
# Mount:
#   /upstream  — read-only Amazon source (platform.tar + build_kernel.tar.gz)
#   /kernel-out — writable output directory
#
# Inside the container we:
#   a. Extract build_kernel.tar.gz to get Amazon's build scripts
#   b. Invoke build_kernel.sh with the pre-baked toolchain (skip git clone)
#   c. Copy arch/arm64/boot/ output to /kernel-out

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Removing stale container '$CONTAINER'..."
  docker rm -f "$CONTAINER" >/dev/null
fi

echo "Starting kernel build in container '$CONTAINER' (jobs=$JOBS) ..."
docker run \
  --name "$CONTAINER" \
  -v "$UPSTREAM:/upstream:ro" \
  -v "$KERNEL_OUT:/kernel-out" \
  "$DOCKER_IMAGE" \
  bash -lc "
set -euo pipefail

TMPDIR=\$(mktemp -d)
trap 'rm -rf \$TMPDIR' EXIT

# Extract Amazon build scripts
echo '==> Extracting build_kernel.tar.gz ...'
tar -xzf /upstream/build_kernel.tar.gz -C \"\$TMPDIR\"

BUILD_SCRIPT=\"\$TMPDIR/build_kernel.sh\"
CONFIG_SCRIPT=\"\$TMPDIR/build_kernel_config.sh\"

# Source the config to get kernel metadata
source \"\$CONFIG_SCRIPT\"
echo \"==> KERNEL_SUBPATH=\$KERNEL_SUBPATH\"
echo \"==> DEFCONFIG_NAME=\$DEFCONFIG_NAME\"
echo \"==> TARGET_ARCH=\$TARGET_ARCH\"

# Extract kernel source from platform.tar
SRC_DIR=\"\$TMPDIR/src\"
mkdir -p \"\$SRC_DIR\"
echo '==> Extracting platform.tar (kernel source only, this may take a while) ...'
tar -xf /upstream/platform.tar -C \"\$SRC_DIR\" \"\$KERNEL_SUBPATH\"

# Fix 32-bit iptables on arm64 kernel: Amazon/MTK compat netfilter clears
# xt_alloc_table_info() per-CPU entry pointers, then panics in memcpy().
for f in \
  \"\$SRC_DIR/\$KERNEL_SUBPATH/net/ipv4/netfilter/ip_tables.c\" \
  \"\$SRC_DIR/\$KERNEL_SUBPATH/net/ipv6/netfilter/ip6_tables.c\"; do
  perl -0pi -e 's/\n\tmemset\(newinfo->entries, 0, size\);/\n\t\/* biscuit: removed bogus memset; xt_alloc_table_info already sets per-cpu entry pointers. *\//g' \"\$f\"
done

OUT_DIR=\"\$TMPDIR/out\"
mkdir -p \"\$OUT_DIR\"

TOOLCHAIN_PREFIX=\"/toolchain/aarch64-linux-android-4.9/bin/aarch64-linux-android-\"
MAKE_ARGS=\"-C \$KERNEL_SUBPATH O=\$OUT_DIR ARCH=\$TARGET_ARCH CROSS_COMPILE=\$TOOLCHAIN_PREFIX\"

echo '==> make defconfig ...'
pushd \"\$SRC_DIR\" >/dev/null
make \$MAKE_ARGS \$DEFCONFIG_NAME

# Apply trapz.config if present
TRAPZ=\"\$SRC_DIR/\$KERNEL_SUBPATH/arch/\$TARGET_ARCH/configs/trapz.config\"
if [[ -f \"\$TRAPZ\" ]]; then
  echo '==> Appending trapz.config ...'
  cat \"\$TRAPZ\" >> \"\$OUT_DIR/.config\"
fi

echo '==> make oldconfig ...'
# ponytail: </dev/null avoids yes-pipe SIGPIPE + pipefail trap; accepts Kconfig defaults for new symbols
make \$MAKE_ARGS oldconfig </dev/null

echo '==> make headers_install ...'
make \$MAKE_ARGS headers_install

# Copy prebuilt headers from build_kernel.tar.gz
if [[ -d \"\$TMPDIR/prebuilt\" ]]; then
  echo '==> Copying Amazon prebuilt headers ...'
  cp -av \"\$TMPDIR/prebuilt/\"* \"\$OUT_DIR/\"
fi

echo '==> make -j$JOBS ...'
make \$MAKE_ARGS -j$JOBS

popd >/dev/null

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

# ── 5. Copy kernel to prebuilt/ ──────────────────────────────────────────────
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
source=amazon-source
kernel=${KERNEL_IMAGE#$REPO_ROOT/}
tarball=workspace/downloads/$(cat "$SENTINEL")
sha256=$(awk '{print $1}' "$DOWNLOADS/$(cat "$SENTINEL").sha256" 2>/dev/null || true)
container=$CONTAINER
log=docker logs $CONTAINER
reason=official Amazon Echo Dot 5.5.5.4 platform.tar kernel, biscuit_defconfig, CM12/netfilter fix, Image.gz-dtb
EOF
cp "$PREBUILT_DIR/kernel-selection.txt" "$CM12_PREBUILT_DIR/kernel-selection.txt"

echo ""
echo "Kernel build complete."
echo "  Image:   $KERNEL_IMAGE"
echo "  Prebuilt: $PREBUILT_DIR/kernel"
echo ""
echo "Logs: docker logs $CONTAINER"
echo "Next: run workspace/scripts/build-boot-img.sh once CM12 ramdisk is available."
