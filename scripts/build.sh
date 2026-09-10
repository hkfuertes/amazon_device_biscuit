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
LUNCH_TARGET="${LUNCH_TARGET:-cm_biscuit-userdebug}"
CLEAN_BISCUIT_OUT="${CLEAN_BISCUIT_OUT:-0}"
BUILD_KERNEL="${BUILD_KERNEL:-0}"
WEBVIEW_PREBUILT="${WEBVIEW_PREBUILT:-yes}"

# --- product-scoped patch profile ---
case "$LUNCH_TARGET" in
  cm_biscuit-userdebug)
    PATCH_PROFILE=full
    OTA_PREFIX=ota_biscuit
    ;;
  biscuit_minimal-userdebug)
    PATCH_PROFILE=minimal
    OTA_PREFIX=ota_biscuit_minimal
    WEBVIEW_PREBUILT=no
    ;;
  *)
    echo "ERROR: unsupported LUNCH_TARGET '$LUNCH_TARGET' (expected cm_biscuit-userdebug or biscuit_minimal-userdebug)" >&2
    exit 1
    ;;
esac
case "$WEBVIEW_PREBUILT" in
  yes|no) ;;
  *)
    echo "ERROR: WEBVIEW_PREBUILT must be yes or no" >&2
    exit 1
    ;;
esac
PATCH_DIR="$REPO_ROOT/patches/$PATCH_PROFILE"

# --- canonical OTA zip name for OTA builds (fail fast, before Docker) ---
CANONICAL_NAME=
if [[ "$BUILD_TARGET" == otapackage ]]; then
  BUILD_DATE="$(date -u +%Y%m%d)"
  BUILD_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
  CANONICAL_NAME="${OTA_PREFIX}_${BUILD_DATE}-${BUILD_SHA}.zip"
fi

if [[ "$BUILD_KERNEL" == 1 ]]; then
  "$REPO_ROOT/scripts/build-kernel.sh"
fi

# --- preflight: source tree must match tracked inputs ---
echo "WebView prebuilt: $WEBVIEW_PREBUILT"
WEBVIEW_PREBUILT="$WEBVIEW_PREBUILT" "$REPO_ROOT/scripts/stage-tree.sh"
PATCH_PROFILE="$PATCH_PROFILE" PATCH_DIR="$PATCH_DIR" "$REPO_ROOT/scripts/apply-patches.sh"

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
  -e CANONICAL_NAME="$CANONICAL_NAME" \
  -e BISCUIT_PREBUILT_WEBVIEW="$WEBVIEW_PREBUILT" \
  "$IMAGE" \
  bash -lc "
    set -e
    if [[ '$CLEAN_BISCUIT_OUT' == 1 ]]; then
      rm -rf '$OUT_DIR/target/product/biscuit'
    fi
    source build/envsetup.sh >/dev/null
    lunch '$LUNCH_TARGET' >/tmp/lunch.log
    export OUT_DIR='$OUT_DIR'
    export PATH=\"\$OUT_DIR/host/linux-x86/bin:\$PATH\"
    make -j'$BUILD_JOBS' '$BUILD_TARGET'
    if [[ '$BUILD_TARGET' == otapackage ]]; then
      # ponytail: exactly one OTA ZIP expected; refuse to guess if the glob is ambiguous.
      shopt -s nullglob
      zips=(\"\$OUT_DIR/target/product/biscuit\"/*-ota-*.zip)
      if [[ \${#zips[@]} -ne 1 ]]; then
        echo \"ERROR: expected exactly one *-ota-*.zip in \$OUT_DIR/target/product/biscuit, found \${#zips[@]}\" >&2
        exit 1
      fi
      mv \"\${zips[0]}\" \"\$OUT_DIR/target/product/biscuit/\$CANONICAL_NAME\"
      echo \"Renamed OTA to \$CANONICAL_NAME\"
    fi
  "

if [[ -n "$CANONICAL_NAME" ]]; then
  echo "Build started ($BUILD_TARGET, $LUNCH_TARGET -> $CANONICAL_NAME). Output: $OUT_DIR"
else
  echo "Build started ($BUILD_TARGET, $LUNCH_TARGET). Output: $OUT_DIR"
fi
echo "Logs: docker logs -f $CONTAINER"
