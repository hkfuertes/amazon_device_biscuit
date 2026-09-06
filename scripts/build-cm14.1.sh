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

"$REPO_ROOT/scripts/stage-cm14.1-tree.sh"
[[ -f "$KERNEL_SOURCE/Makefile" && \
   -f "$KERNEL_SOURCE/arch/arm/configs/biscuit_defconfig" && \
   -f "$KERNEL_SUPPORT/verity-keys" && \
   -f "$KERNEL_SUPPORT/include/generated/trapz_generated_kernel.h" ]] || {
  echo "ERROR: staged FireOS 6 kernel source/support is incomplete" >&2
  exit 1
}

mkdir -p "$KERNEL_OUT/include/generated"
install -m 0644 "$KERNEL_SUPPORT/verity-keys" "$KERNEL_OUT/verity-keys"
install -m 0644 "$KERNEL_SUPPORT/include/generated/trapz_generated_kernel.h" \
  "$KERNEL_OUT/include/generated/trapz_generated_kernel.h"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "ERROR: Docker image '$IMAGE' not found." >&2
  echo "Build it first:" >&2
  echo "  docker build -t $IMAGE -f $REPO_ROOT/docker/cm14.1-ubuntu20.Dockerfile $REPO_ROOT/docker/" >&2
  exit 1
fi

ln -sfn out-docker "$CM14/out"
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
    export PATH=\"\$OUT_DIR/host/linux-x86/bin:\$PATH\"
    lunch cm_biscuit-userdebug >/tmp/lunch.log
    make -j'$BUILD_JOBS' '$BUILD_TARGET'
  "

echo "Started $CONTAINER ($BUILD_TARGET, FireOS 6 kernel from source)."
echo "Monitor: docker logs -f $CONTAINER"
