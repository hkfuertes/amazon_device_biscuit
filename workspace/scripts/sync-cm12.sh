#!/usr/bin/env bash
# Sync a pinned CM12 checkout into workspace/cm12 from manifest/cm12.lock.xml.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CM12="$REPO_ROOT/workspace/cm12"
LOCK="$REPO_ROOT/manifest/cm12.lock.xml"
REPO_BIN="${REPO_BIN:-}"

[[ -f "$LOCK" ]] || { echo "ERROR: missing $LOCK" >&2; exit 1; }
mkdir -p "$CM12" "$REPO_ROOT/workspace/bin"

if [[ -z "$REPO_BIN" ]]; then
  if command -v repo >/dev/null 2>&1; then
    REPO_BIN="repo"
  else
    REPO_BIN="$REPO_ROOT/workspace/bin/repo"
    if [[ ! -x "$REPO_BIN" ]]; then
      curl -L --fail -o "$REPO_BIN" https://storage.googleapis.com/git-repo-downloads/repo
      chmod +x "$REPO_BIN"
    fi
  fi
fi

cd "$CM12"
"$REPO_BIN" init -u https://github.com/CyanogenMod/android.git -b cm-12.1
cp "$LOCK" .repo/manifests/cm12.lock.xml
"$REPO_BIN" init -m cm12.lock.xml
"$REPO_BIN" sync -c -j"${SYNC_JOBS:-4}"
