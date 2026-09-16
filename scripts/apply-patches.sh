#!/usr/bin/env bash
# Apply every *.patch in one directory, sorted, fuzz-free and idempotently.
set -euo pipefail

usage() {
  echo "usage: $0 <target-root> <strip-level> <patch-dir>" >&2
}

[[ $# == 3 ]] || { usage; exit 2; }
ROOT="$1"
STRIP="$2"
PATCH_DIR="$3"
PATCH_REAPPLY="${PATCH_REAPPLY:-0}"
PATCH_REVERSE_ONLY="${PATCH_REVERSE_ONLY:-0}"
PATCH_STATE_DIR="${PATCH_STATE_DIR:-}"

[[ -d "$ROOT" ]] || { echo "ERROR: target root missing: $ROOT" >&2; exit 1; }
[[ -d "$PATCH_DIR" ]] || { echo "ERROR: patch directory missing: $PATCH_DIR" >&2; exit 1; }
[[ "$STRIP" =~ ^[0-9]+$ ]] || { echo "ERROR: strip level must be numeric: $STRIP" >&2; exit 1; }

mapfile -d '' PATCHES < <(LC_ALL=C find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' -print0 | LC_ALL=C sort -z)

patch_manifest() {
  for patch_file in "${PATCHES[@]}"; do
    sha256sum "$patch_file"
  done | sha256sum | awk '{print $1}'
}

state_file=""
if [[ -n "$PATCH_STATE_DIR" ]]; then
  mkdir -p "$PATCH_STATE_DIR"
  state_file="$PATCH_STATE_DIR/$(basename "$PATCH_DIR")-p$STRIP.sha256"
  manifest="$(patch_manifest)"
  if [[ "$PATCH_REAPPLY" == 1 && -f "$state_file" && "$(cat "$state_file")" == "$manifest" ]]; then
    echo "SKIP patch directory unchanged ${PATCH_DIR#$PWD/}"
    exit 0
  fi
fi

cleanup_patch_backups() {
  find "$ROOT" -name '*.orig' -type f -delete
}

try_reverse_patch() {
  local patch_file="$1"
  patch --batch --forward --fuzz=0 --dry-run -R -d "$ROOT" -p"$STRIP" <"$patch_file" >/dev/null 2>&1
}

reverse_applied_patches() {
  local i patch_file count
  for ((i=${#PATCHES[@]}-1; i>=0; i--)); do
    patch_file="${PATCHES[$i]}"
    count=0
    while try_reverse_patch "$patch_file"; do
      patch --batch --forward --fuzz=0 -R -d "$ROOT" -p"$STRIP" <"$patch_file" >/dev/null
      echo "UNAPPLIED ${patch_file#$PWD/}"
      count=$((count + 1))
      if ((count > 20)); then
        echo "ERROR: too many reverse applications for ${patch_file#$PWD/}" >&2
        exit 1
      fi
    done
  done
}

cleanup_patch_backups
if [[ "$PATCH_REAPPLY" == 1 || "$PATCH_REVERSE_ONLY" == 1 ]]; then
  reverse_applied_patches
fi

if [[ "$PATCH_REVERSE_ONLY" == 1 ]]; then
  cleanup_patch_backups
  exit 0
fi

for patch_file in "${PATCHES[@]}"; do
  rel="${patch_file#$PWD/}"
  if patch --batch --forward --fuzz=0 --dry-run -d "$ROOT" -p"$STRIP" <"$patch_file" >/dev/null; then
    patch --batch --forward --fuzz=0 -d "$ROOT" -p"$STRIP" <"$patch_file" >/dev/null
    echo "APPLIED $rel"
  elif [[ "$PATCH_REAPPLY" != 1 ]] && try_reverse_patch "$patch_file"; then
    echo "SKIP already applied $rel"
  else
    echo "ERROR: patch does not apply cleanly: $rel" >&2
    patch --batch --forward --fuzz=0 --dry-run -d "$ROOT" -p"$STRIP" <"$patch_file"
    exit 1
  fi
done
cleanup_patch_backups

if [[ -n "$state_file" ]]; then
  printf '%s\n' "$manifest" >"$state_file"
fi
