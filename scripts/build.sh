#!/usr/bin/env bash
# Build CM12 for Biscuit inside a stable named Docker container.
# ponytail: no --rm so logs survive; remove old container first for idempotency.
set -euo pipefail

IMAGE="cm12-ubuntu14:latest"
CONTAINER="cm12-biscuit-build"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM12_DIR="$REPO_ROOT/workspace/cm12"
OUT_DIR="$CM12_DIR/out-docker"   # absolute, required by amonet remap
BUILD_TARGET="${BUILD_TARGET:-otapackage}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
CLEAN_BISCUIT_OUT="${CLEAN_BISCUIT_OUT:-0}"
BUILD_KERNEL="${BUILD_KERNEL:-0}"

if [[ "$BUILD_KERNEL" == 1 ]]; then
  "$REPO_ROOT/scripts/build-kernel.sh"
fi

# --- preflight: source tree must match tracked inputs ---
"$REPO_ROOT/scripts/stage-tree.sh"
"$REPO_ROOT/scripts/apply-patches.sh"

# --- preflight: image must exist ---
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "ERROR: Docker image '$IMAGE' not found."
  echo "Build it first:"
  echo "  docker build -t $IMAGE -f $REPO_ROOT/docker/cm12-ubuntu14.Dockerfile $REPO_ROOT/docker/"
  exit 1
fi

# CM vendor packaging has a hardcoded out/ lookup even when OUT_DIR is set.
# ponytail: symlink beats patching legacy CM makefiles.
ln -sfn out-docker "$CM12_DIR/out"

# --- remove stale container (idempotent) ---
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Removing previous container '$CONTAINER'..."
  docker rm -f "$CONTAINER" >/dev/null
fi

# --- run build detached (no --rm: keep logs) ---
echo "Starting build in detached container '$CONTAINER'..."
docker run -d \
  --name "$CONTAINER" \
  -v "$REPO_ROOT:$REPO_ROOT" \
  -w "$CM12_DIR" \
  "$IMAGE" \
  bash -lc "
    if [[ '$CLEAN_BISCUIT_OUT' == 1 ]]; then
      rm -rf \
        '$OUT_DIR/target/product/biscuit/system' \
        '$OUT_DIR/target/product/biscuit/symbols/system/lib/hw/audio.primary.mt8163.so' \
        '$OUT_DIR/target/product/biscuit/obj/PACKAGING' \
        '$OUT_DIR/target/product/biscuit/obj/lib/audio.primary.mt8163.so' \
        '$OUT_DIR/target/product/biscuit/obj/SHARED_LIBRARIES/audio.primary.mt8163_intermediates'
    fi
    source build/envsetup.sh >/dev/null
    lunch cm_biscuit-userdebug >/tmp/lunch.log
    export OUT_DIR='$OUT_DIR'
    export PATH=\"\$OUT_DIR/host/linux-x86/bin:\$PATH\"
    make -j'$BUILD_JOBS' '$BUILD_TARGET'
  "

echo "Build started ($BUILD_TARGET). Output: $OUT_DIR"
echo "Logs: docker logs -f $CONTAINER"
