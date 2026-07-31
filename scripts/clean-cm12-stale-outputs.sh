#!/usr/bin/env bash
# Remove stale generated CM12 outputs that incremental builds may keep around.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM12="${CM12:-$REPO_ROOT/workspace/cm12}"

for out in "$CM12"/out "$CM12"/out-*; do
  [[ -d "$out/target/product" ]] || continue
  for product in "$out"/target/product/*; do
    [[ -d "$product" ]] || continue
    rm -rf "$product/system/etc/security/cacerts" "$product/system/etc/security/cacerts.pem"
    rm -rf "$product"/obj/ETC/target-cacert-*_intermediates "$product"/obj/ETC/cacerts.pem_intermediates
    rm -f "$product/system/etc/media_codecs"*.xml "$product/system/etc/mtk_omx_core.cfg"
    rm -rf "$product"/obj/ETC/media_codecs*_intermediates "$product"/obj/ETC/mtk_omx_core.cfg_intermediates
    echo "CLEANED stale outputs in ${product#$REPO_ROOT/}"
  done
done
