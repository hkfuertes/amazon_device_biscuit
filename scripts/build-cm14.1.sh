#!/usr/bin/env bash
# Launch the CM14.1 Biscuit compile baseline in a detached container.
set -euo pipefail

IMAGE="cm14.1-ubuntu20:latest"
CONTAINER="cm14.1-biscuit-build"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM14="${CM14:-$REPO_ROOT/workspace/cm14.1}"
OUT_DIR="$CM14/out-docker"
KERNEL_SOURCE="$CM14/kernel/amazon/biscuit"
KERNEL_SUPPORT="$CM14/device/amazon/biscuit/kernel-build-support"
KERNEL_OUT="$OUT_DIR/target/product/biscuit/obj/KERNEL_OBJ"
BUILD_TARGET="${BUILD_TARGET:-otapackage}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
CCACHE_DIR="${CCACHE_DIR:-$REPO_ROOT/workspace/ccache}"
CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-50G}"

"$REPO_ROOT/scripts/stage-cm14.1-tree.sh"
[[ -f "$KERNEL_SOURCE/Makefile" && \
   -f "$KERNEL_SOURCE/arch/arm/configs/biscuit_defconfig" && \
   -f "$KERNEL_SUPPORT/verity-keys" && \
   -f "$KERNEL_SUPPORT/include/generated/trapz_generated_kernel.h" ]] || {
  echo "ERROR: staged FireOS 6 kernel source/support is incomplete" >&2
  exit 1
}

install_if_changed() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    return 0
  fi
  install -m 0644 "$src" "$dst"
}

install_if_changed "$KERNEL_SUPPORT/verity-keys" "$KERNEL_OUT/verity-keys"
install_if_changed "$KERNEL_SUPPORT/include/generated/trapz_generated_kernel.h" \
  "$KERNEL_OUT/include/generated/trapz_generated_kernel.h"

# ponytail: incremental Android builds do not delete files removed from PRODUCT_COPY_FILES.
for stale in \
  system/bin/6620_launcher \
  system/bin/linker64 \
  system/bin/wmt_loader \
  system/etc/firmware/ROMv2_lm_patch_1_0_hdr.bin \
  system/etc/firmware/ROMv2_lm_patch_1_1_hdr.bin \
  system/etc/firmware/WIFI_RAM_CODE_8163 \
  system/lib64/libc.so \
  system/lib64/libcutils.so \
  system/lib64/libdl.so \
  system/lib64/liblog.so \
  system/lib64/libm.so \
  system/lib64/libstdc++.so; do
  rm -f "$OUT_DIR/target/product/biscuit/$stale"
done
rmdir "$OUT_DIR/target/product/biscuit/system/lib64" 2>/dev/null || true

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "ERROR: Docker image '$IMAGE' not found." >&2
  echo "Build it first:" >&2
  echo "  docker build -t $IMAGE -f $REPO_ROOT/docker/cm14.1-ubuntu20.Dockerfile $REPO_ROOT/docker/" >&2
  exit 1
fi

ln -sfn out-docker "$CM14/out"
mkdir -p "$CCACHE_DIR"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

docker run -d \
  --name "$CONTAINER" \
  -v "$REPO_ROOT:$REPO_ROOT" \
  -w "$CM14" \
  "$IMAGE" \
  bash -lc "
    set -e
    source build/envsetup.sh >/dev/null
    export OUT_DIR='$OUT_DIR'
    export USE_CCACHE=1
    export CCACHE_DIR='$CCACHE_DIR'
    prebuilts/misc/linux-x86/ccache/ccache -M '$CCACHE_MAXSIZE' >/dev/null || true
    export PATH=\"\$OUT_DIR/host/linux-x86/bin:\$PATH\"
    lunch cm_biscuit-userdebug >/tmp/lunch.log
    make -j'$BUILD_JOBS' '$BUILD_TARGET'
  "

echo "Started $CONTAINER ($BUILD_TARGET, FireOS 6 kernel from source)."
echo "Monitor: docker logs -f $CONTAINER"
