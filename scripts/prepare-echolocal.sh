#!/usr/bin/env bash
# Fetch the verified release daemon and pin the source-only model assets.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${ECHOLOCAL_VERSION:-0.0.6}"
RELEASE_URL="${ECHOLOCAL_RELEASE_URL:-https://github.com/ygelfand/echolocal/releases/download/${VERSION}/echod}"
RELEASE_SHA256="${ECHOLOCAL_RELEASE_SHA256:-155a9d1330879de6f889a3990f2e82d1ecf5ddf97c7e6d1b4d85babe6f192181}"
SOURCE_URL="${ECHOLOCAL_SOURCE_URL:-https://github.com/ygelfand/echolocal.git}"
SOURCE_REV="${ECHOLOCAL_SOURCE_REV:-567d9440f48509457cf1c7131745e385fabf83c1}"
ARTIFACT_DIR="${ECHOLOCAL_ARTIFACT_DIR:-$REPO_ROOT/workspace/echolocal-release/$VERSION}"
SOURCE_DIR="${ECHOLOCAL_SOURCE_DIR:-$REPO_ROOT/workspace/echolocal-source}"
ARTIFACT="$ARTIFACT_DIR/echod"
MODEL_DIR="$SOURCE_DIR/internal/host/assets/models"
MODELS=(okay_nabu hey_jarvis hey_mycroft)

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

for command in curl git readelf sha256sum; do
    command -v "$command" >/dev/null || fail "missing required host command: $command"
done

mkdir -p "$ARTIFACT_DIR"
if [[ ! -f "$ARTIFACT" ]] || [[ "$(sha256sum "$ARTIFACT" | awk '{print $1}')" != "$RELEASE_SHA256" ]]; then
    temp="$(mktemp "$ARTIFACT.XXXXXX")"
    trap 'rm -f "$temp"' EXIT
    curl --fail --location --retry 3 --connect-timeout 15 --output "$temp" "$RELEASE_URL"
    mv -f "$temp" "$ARTIFACT"
    trap - EXIT
fi

actual_sha="$(sha256sum "$ARTIFACT" | awk '{print $1}')"
[[ "$actual_sha" == "$RELEASE_SHA256" ]] || fail "echod SHA-256 mismatch"
chmod 0755 "$ARTIFACT"
header="$(readelf -h "$ARTIFACT")"
grep -Eq 'Class:[[:space:]]+ELF64' <<<"$header" || fail "echod is not ELF64"
grep -Eq 'Type:[[:space:]]+EXEC' <<<"$header" || fail "echod is not an executable ELF"
grep -Eq 'Machine:[[:space:]]+AArch64' <<<"$header" || fail "echod is not AArch64"
if readelf -d "$ARTIFACT" | grep -q '(NEEDED)'; then
    fail "echod must be statically linked"
fi

if [[ -e "$SOURCE_DIR" && ! -d "$SOURCE_DIR/.git" ]]; then
    fail "EchoLocal source path is not a Git checkout: $SOURCE_DIR"
fi
if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    git clone "$SOURCE_URL" "$SOURCE_DIR"
fi
[[ -z "$(git -C "$SOURCE_DIR" status --porcelain)" ]] || fail "EchoLocal source checkout is dirty: $SOURCE_DIR"
if ! git -C "$SOURCE_DIR" cat-file -e "$SOURCE_REV^{commit}" 2>/dev/null; then
    git -C "$SOURCE_DIR" fetch --no-tags origin "$SOURCE_REV"
fi
git -C "$SOURCE_DIR" checkout --detach "$SOURCE_REV" >/dev/null
[[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" == "$SOURCE_REV" ]] || fail "EchoLocal source revision mismatch"

for model in "${MODELS[@]}"; do
    [[ -f "$MODEL_DIR/$model.json" ]] || fail "missing EchoLocal model manifest: $model"
    [[ -f "$MODEL_DIR/$model.tflite" ]] || fail "missing EchoLocal model: $model"
done

echo "EchoLocal $VERSION ready: $ARTIFACT"
echo "EchoLocal model source pinned: $SOURCE_REV"
