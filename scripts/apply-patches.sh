#!/usr/bin/env bash
# Apply tracked CM12 patches. Safe to re-run: skips already-applied patches.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM12="$REPO_ROOT/workspace/cm12"

[[ -d "$CM12/build" ]] || { echo "ERROR: CM12 not synced at $CM12" >&2; exit 1; }

delete_patch_backups() {
  # patch(1) backup files under res/ are treated as resources by aapt.
  find "$CM12" -path '*/res/*' -name '*.orig' -type f -delete
}

delete_patch_backups

for patch in "$REPO_ROOT"/patches/*.patch; do
  [[ -e "$patch" ]] || continue
  rel="${patch#$REPO_ROOT/}"
  case "$(basename "$patch")" in
    biscuit-kernel-*.patch)
      echo "SKIP kernel-only patch $rel"
      continue
      ;;
  esac
  if patch -d "$CM12" -p1 --forward --batch --dry-run --silent < "$patch" >/dev/null 2>&1; then
    patch -d "$CM12" -p1 --forward --batch --silent < "$patch"
    echo "APPLIED $rel"
  elif patch -d "$CM12" -p1 -R --forward --batch --dry-run --silent < "$patch" >/dev/null 2>&1; then
    echo "SKIP already applied $rel"
  else
    echo "ERROR: patch does not apply cleanly: $rel" >&2
    patch -d "$CM12" -p1 --forward --batch --dry-run < "$patch"
    exit 1
  fi
done

delete_patch_backups
