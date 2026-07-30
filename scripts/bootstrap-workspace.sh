#!/usr/bin/env bash
# Recreate ignored workspace from tracked recipe + internet/local inputs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p \
  "$REPO_ROOT/workspace/downloads" \
  "$REPO_ROOT/workspace/extracted" \
  "$REPO_ROOT/workspace/upstream" \
  "$REPO_ROOT/workspace/cm12" \
  "$REPO_ROOT/workspace/vendor" \
  "$REPO_ROOT/workspace/device/amazon/biscuit/prebuilt"

"$REPO_ROOT/scripts/prepare-kernel-source.sh"
"$REPO_ROOT/scripts/update-ca-certs.sh"

if [[ "${SKIP_CM12_SYNC:-0}" != 1 ]]; then
  "$REPO_ROOT/scripts/sync-cm12.sh"
fi

if [[ ! -f "${BISCUIT_SYSTEM_IMG:-$REPO_ROOT/workspace/extracted/biscuit-stock-272.6.4.1/system.img}" ]]; then
  "$REPO_ROOT/scripts/prepare-biscuit-stock-system-image.sh"
fi
"$REPO_ROOT/scripts/extract-biscuit-stock-blobs.sh" "${BISCUIT_SYSTEM_IMG:-$REPO_ROOT/workspace/extracted/biscuit-stock-272.6.4.1/system.img}"

if [[ -d "$REPO_ROOT/workspace/cm12/build" ]]; then
  "$REPO_ROOT/scripts/stage-tree.sh"
  "$REPO_ROOT/scripts/apply-patches.sh"
fi

echo "Workspace bootstrap done."
