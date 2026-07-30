#!/usr/bin/env bash
# Reset generated workspace state while keeping the CM12 checkout (no reclone).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM12="$REPO_ROOT/workspace/cm12"

if [[ -d "$CM12/.repo" ]]; then
  echo "Cleaning CM12 checkout without reclone ..."
  REPO_BIN="${REPO_BIN:-$CM12/.repo/repo/repo}"
  [[ -x "$REPO_BIN" ]] || REPO_BIN="repo"
  (
    cd "$CM12"
    "$REPO_BIN" forall -c 'git reset --hard >/dev/null && git clean -fdx >/dev/null'
  )
  rm -rf "$CM12/out" "$CM12/out-docker"
else
  echo "WARN: no CM12 checkout at $CM12"
fi

rm -rf \
  "$REPO_ROOT/workspace/bin" \
  "$REPO_ROOT/workspace/cacerts" \
  "$REPO_ROOT/workspace/cacerts.pem" \
  "$REPO_ROOT/workspace/device" \
  "$REPO_ROOT/workspace/extracted" \
  "$REPO_ROOT/workspace/kernel" \
  "$REPO_ROOT/workspace/kernel-out" \
  "$REPO_ROOT/workspace/tmp" \
  "$REPO_ROOT/workspace/upstream" \
  "$REPO_ROOT/workspace/vendor"

mkdir -p \
  "$REPO_ROOT/workspace/downloads" \
  "$REPO_ROOT/workspace/logs" \
  "$REPO_ROOT/workspace/tmp"

echo "Workspace reset done (kept workspace/cm12)."
