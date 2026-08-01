#!/usr/bin/env bash
# Sync a pinned CM12 checkout into workspace/cm12 from manifest/cm12.lock.xml.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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
INIT_ARGS=(-u https://github.com/CyanogenMod/android.git -b cm-12.1)
if [[ -n "${CM12_REFERENCE:-}" ]]; then
  INIT_ARGS+=(--reference "$CM12_REFERENCE")
fi
CM12_DEPTH="${CM12_DEPTH:-1}"
INIT_ARGS+=(--depth "$CM12_DEPTH")
"$REPO_BIN" init "${INIT_ARGS[@]}"
cp "$LOCK" .repo/manifests/cm12.lock.xml
"$REPO_BIN" init -m cm12.lock.xml
for attempt in 1 2 3; do
  if "$REPO_BIN" sync -c --no-tags --fail-fast -j"${SYNC_JOBS:-4}"; then
    exit 0
  fi
  echo "repo sync failed (attempt $attempt/3)" >&2
  sleep $((attempt * 10))
done
exit 1
