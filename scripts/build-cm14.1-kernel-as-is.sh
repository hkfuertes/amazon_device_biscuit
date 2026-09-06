#!/usr/bin/env bash
# Build Amazon's FireOS 6.5.7.1 Biscuit kernel unchanged in a detached container.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE="6.5.7.1"
SOURCE_URL="https://fireos-audio-src.s3.amazonaws.com/dMUQiRDxI3hFuRDaF0WTumrp71/Echo_Dot_src-6.5.7.1-20251024.tar.bz2"
SOURCE_SHA256="2f6b7eed8c09cecf7633f01909c6a4085bef691c29ed0d106c75e7b48c7b4721"
ARCHIVE="$REPO_ROOT/workspace/downloads/$(basename "$SOURCE_URL")"
SOURCE_DIR="$REPO_ROOT/workspace/upstream/amazon-echo-dot-$RELEASE"
OUT_DIR="$REPO_ROOT/workspace/out/fireos-$RELEASE-kernel-as-is"
IMAGE="biscuit-kernel-builder:latest"
CONTAINER="fireos6-biscuit-kernel-as-is"

mkdir -p "$(dirname "$ARCHIVE")" "$(dirname "$SOURCE_DIR")" "$(dirname "$OUT_DIR")"
if [[ ! -f "$ARCHIVE" ]]; then
  curl --fail --location --progress-bar -o "$ARCHIVE" "$SOURCE_URL"
fi
printf '%s  %s\n' "$SOURCE_SHA256" "$ARCHIVE" | sha256sum -c -

if [[ ! -f "$SOURCE_DIR/platform.tar" || ! -f "$SOURCE_DIR/build_kernel.sh" || ! -d "$SOURCE_DIR/prebuilt" ]]; then
  rm -rf "$SOURCE_DIR"
  mkdir -p "$SOURCE_DIR"
  tar --no-same-owner --no-same-permissions -xjf "$ARCHIVE" -C "$SOURCE_DIR" \
    platform.tar build_kernel.sh build_kernel_config.sh prebuilt
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "ERROR: Docker image '$IMAGE' is missing." >&2
  echo "Build it first: docker build -t $IMAGE -f $REPO_ROOT/docker/biscuit-kernel-builder.Dockerfile $REPO_ROOT/docker/" >&2
  exit 1
fi

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
docker run -d \
  --name "$CONTAINER" \
  --user "$(id -u):$(id -g)" \
  -v "$SOURCE_DIR:/fireos:ro" \
  -v "$OUT_DIR:/out" \
  "$IMAGE" \
  bash /fireos/build_kernel.sh /fireos/platform.tar /out

echo "Started $CONTAINER (FireOS $RELEASE kernel as-is)."
echo "Monitor: docker logs -f $CONTAINER"
