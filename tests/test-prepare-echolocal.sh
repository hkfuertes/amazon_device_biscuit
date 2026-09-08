#!/usr/bin/env bash
# Exercise release verification and model checkout without network access.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
release="$tmp/release"
source_repo="$tmp/source-repo"
cache="$tmp/cache"
mkdir -p "$release" "$source_repo/internal/host/assets/models"

python3 - "$release/echod" <<'PY'
import pathlib
import struct
import sys

header = bytearray(64)
header[:16] = b'\x7fELF' + bytes([2, 1, 1, 0]) + bytes(8)
struct.pack_into('<HHIQQQIHHHHHH', header, 16, 2, 183, 1, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0)
pathlib.Path(sys.argv[1]).write_bytes(header)
PY

for model in okay_nabu hey_jarvis hey_mycroft; do
    printf '%s\n' '{"type":"micro"}' > "$source_repo/internal/host/assets/models/$model.json"
    printf '%s\n' "$model" > "$source_repo/internal/host/assets/models/$model.tflite"
done

git -C "$source_repo" init -q
git -C "$source_repo" config user.email test@example.invalid
git -C "$source_repo" config user.name test
git -C "$source_repo" add .
git -C "$source_repo" commit -qm models
revision="$(git -C "$source_repo" rev-parse HEAD)"
sha="$(sha256sum "$release/echod" | awk '{print $1}')"

ECHOLOCAL_RELEASE_URL="file://$release/echod" \
ECHOLOCAL_RELEASE_SHA256="$sha" \
ECHOLOCAL_ARTIFACT_DIR="$cache/release" \
ECHOLOCAL_SOURCE_URL="$source_repo" \
ECHOLOCAL_SOURCE_DIR="$cache/source" \
ECHOLOCAL_SOURCE_REV="$revision" \
"$ROOT/scripts/prepare-echolocal.sh" >/dev/null

[[ -x "$cache/release/echod" ]]
[[ "$(sha256sum "$cache/release/echod" | awk '{print $1}')" == "$sha" ]]
[[ "$(git -C "$cache/source" rev-parse HEAD)" == "$revision" ]]
for model in okay_nabu hey_jarvis hey_mycroft; do
    [[ -f "$cache/source/internal/host/assets/models/$model.json" ]]
    [[ -f "$cache/source/internal/host/assets/models/$model.tflite" ]]
done

# A verified cache is reusable without a network fetch.
ECHOLOCAL_RELEASE_URL="file://$tmp/missing" \
ECHOLOCAL_RELEASE_SHA256="$sha" \
ECHOLOCAL_ARTIFACT_DIR="$cache/release" \
ECHOLOCAL_SOURCE_URL="$source_repo" \
ECHOLOCAL_SOURCE_DIR="$cache/source" \
ECHOLOCAL_SOURCE_REV="$revision" \
"$ROOT/scripts/prepare-echolocal.sh" >/dev/null

echo 'EchoLocal preparation checks passed'
