#!/usr/bin/env bash
# Disable MTK OMX codec advertisements for Biscuit CM12.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM12="${CM12:-$REPO_ROOT/workspace/cm12}"
CFG="$CM12/vendor/amazon/mt8163-common/proprietary/etc/mtk_omx_core.cfg"

[[ -f "$CFG" ]] || { echo "SKIP MTK OMX disable: missing ${CFG#$REPO_ROOT/}"; exit 0; }

grep -v '^OMX\.MTK' "$CFG" > "$CFG.tmp"
mv "$CFG.tmp" "$CFG"
echo "DISABLED MTK OMX codecs in ${CFG#$REPO_ROOT/} (kept non-OMX.MTK entries)"
