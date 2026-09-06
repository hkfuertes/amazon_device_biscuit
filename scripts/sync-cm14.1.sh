#!/usr/bin/env bash
# Sync CM14.1 and create a resolved lock manifest on the first successful sync.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM14="${CM14:-$REPO_ROOT/workspace/cm14.1}"
LOCAL_MANIFEST="$REPO_ROOT/manifest/cm14.1.local.xml"
LOCK="$REPO_ROOT/manifest/cm14.1.lock.xml"
REPO_BIN="${REPO_BIN:-}"

[[ -f "$LOCAL_MANIFEST" ]] || { echo "ERROR: missing $LOCAL_MANIFEST" >&2; exit 1; }
mkdir -p "$CM14" "$REPO_ROOT/workspace/bin"

command -v git-lfs >/dev/null 2>&1 || {
  echo "ERROR: CM14.1's WebView prebuilt requires git-lfs." >&2
  echo "Install it manually: sudo apt-get install git-lfs" >&2
  exit 1
}

if [[ -z "$REPO_BIN" ]]; then
  if command -v repo >/dev/null 2>&1; then
    REPO_BIN=repo
  else
    REPO_BIN="$REPO_ROOT/workspace/bin/repo"
    if [[ ! -x "$REPO_BIN" ]]; then
      curl -L --fail -o "$REPO_BIN" https://storage.googleapis.com/git-repo-downloads/repo
      chmod +x "$REPO_BIN"
    fi
  fi
fi

cd "$CM14"
INIT_ARGS=(-u https://github.com/LineageOS/android.git -b cm-14.1 --depth "${CM14_DEPTH:-1}")
if [[ -n "${CM14_REFERENCE:-}" ]]; then
  INIT_ARGS+=(--reference "$CM14_REFERENCE")
fi
"$REPO_BIN" init "${INIT_ARGS[@]}"

if [[ -f "$LOCK" ]]; then
  cp "$LOCK" .repo/manifests/cm14.1.lock.xml
  "$REPO_BIN" init -m cm14.1.lock.xml
else
  mkdir -p .repo/local_manifests
  cp "$LOCAL_MANIFEST" .repo/local_manifests/biscuit.xml
fi

for attempt in 1 2 3; do
  if "$REPO_BIN" sync -c --no-tags --fail-fast -j"${SYNC_JOBS:-4}"; then
    if [[ ! -f "$LOCK" ]]; then
      "$REPO_BIN" manifest -r -o "$LOCK"
      echo "Wrote resolved lock manifest: $LOCK"
    fi
    exit 0
  fi
  echo "repo sync failed (attempt $attempt/3)" >&2
  sleep $((attempt * 10))
done
exit 1
