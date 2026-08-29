#!/usr/bin/env bash
# Show CM12 changes that must be represented by patches/cm12/*.patch.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CM12="${CM12:-$REPO_ROOT/workspace/cm12}"
PATCH_DIR="${PATCH_DIR:-$REPO_ROOT/patches/cm12}"
CM12_DIFF_JOBS="${CM12_DIFF_JOBS:-4}"
export LC_ALL=C

[[ -d "$CM12/.repo" ]] || { echo "ERROR: CM12 repo checkout missing at $CM12" >&2; exit 1; }
[[ "$CM12_DIFF_JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "ERROR: CM12_DIFF_JOBS must be a positive integer" >&2; exit 1; }

tmp_changed="$(mktemp)"
tmp_patched="$(mktemp)"
tmp_audited="$(mktemp)"
trap 'rm -f "$tmp_changed" "$tmp_patched" "$tmp_audited"' EXIT

export CM12
echo "Scanning CM12 Git worktrees with $CM12_DIFF_JOBS workers..."
find "$CM12" \
  -path "$CM12/.repo" -prune -o \
  -path "$CM12/out-docker" -prune -o \
  -name .git -print0 |
  xargs -0 -r -P "$CM12_DIFF_JOBS" -n 1 bash -c '
    set -o pipefail
    gitref=$1
    project=${gitref%/.git}
    rel_project=${project#"$CM12/"}
    git -C "$project" diff --no-ext-diff --name-only HEAD | sed "s#^#$rel_project/#"
  ' _ |
  LC_ALL=C sort -u > "$tmp_changed"

while IFS= read -r -d '' p; do
  awk '
    /^diff --git a\// { sub(/^diff --git a\//, ""); sub(/^.* b\//, ""); print }
    /^\+\+\+ b\// { sub(/^\+\+\+ b\//, ""); sub(/\t.*/, ""); print }
  ' "$p"
done < <(find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' -print0 | sort -z) | sort -u > "$tmp_patched"

# Pinned AOSP CA files are a declared materialized input; preflight verifies provenance.
awk '!/^libcore\/luni\/src\/main\/files\/cacerts\//' "$tmp_changed" > "$tmp_audited"

echo "-- CM12 dirty files vs upstream HEAD --"
if [[ -s "$tmp_changed" ]]; then
  cat "$tmp_changed"
else
  echo "none"
fi

echo ""
echo "-- Dirty files missing from patches --"
missing="$(comm -23 "$tmp_audited" "$tmp_patched")"
if [[ -n "$missing" ]]; then
  echo "$missing"
  exit 1
else
  echo "none"
fi

echo ""
echo "-- Patch paths with no dirty counterpart (ok for staged vendor files or unapplied patches) --"
comm -13 "$tmp_audited" "$tmp_patched" || true
