#!/usr/bin/env bash
# Preflight: download, verify, and extract the Amazon Echo Dot 5.5.5.4 source tarball.
# No compilation. No flashing. Safe to re-run.
#
# Configuration (env vars or workspace/downloads/amazon-source.url):
#   AMAZON_SOURCE_URL     — full HTTPS URL to the .tar.bz2  (required)
#   AMAZON_SOURCE_SHA256  — expected SHA-256 hex digest      (optional; computed & stored on first run)
#
# Where to find the URL:
#   https://www.amazon.com/gp/help/customer/display.html?nodeId=201626480
#   Echo Dot 5.5.5.4 source: recorded in AGENTS.md
#   Then: export AMAZON_SOURCE_URL="<paste>" or write it to workspace/downloads/amazon-source.url
#
# Flags:
#   --force-extract   re-extract even if upstream sentinel already matches

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOWNLOADS="$REPO_ROOT/workspace/downloads"
UPSTREAM="$REPO_ROOT/workspace/upstream"
URL_FILE="$DOWNLOADS/amazon-source.url"
mkdir -p "$DOWNLOADS" "$UPSTREAM"

FORCE_EXTRACT=0
for arg in "$@"; do
  [[ "$arg" == "--force-extract" ]] && FORCE_EXTRACT=1
done

# ── 1. Resolve URL ──────────────────────────────────────────────────────────
if [[ -z "${AMAZON_SOURCE_URL:-}" && -f "$URL_FILE" ]]; then
  AMAZON_SOURCE_URL="$(tr -d '[:space:]' < "$URL_FILE")"
fi

if [[ -z "${AMAZON_SOURCE_URL:-}" ]]; then
  echo "ERROR: AMAZON_SOURCE_URL not set and $URL_FILE not found."
  echo ""
  echo "Find the tarball URL in AGENTS.md (Amazon Echo Dot 5.5.5.4 source)."
  echo "Then either:"
  echo "  export AMAZON_SOURCE_URL=<url> && $0"
  echo "  echo '<url>' > $URL_FILE && $0"
  exit 1
fi

TARBALL="$DOWNLOADS/$(basename "$AMAZON_SOURCE_URL")"
SHA256_FILE="${TARBALL}.sha256"

# ── 2. Download if missing ───────────────────────────────────────────────────
if [[ -f "$TARBALL" ]]; then
  echo "Download already present: $TARBALL"
else
  echo "Downloading $AMAZON_SOURCE_URL ..."
  curl -L --fail --progress-bar -o "$TARBALL" "$AMAZON_SOURCE_URL"
  echo "Downloaded: $TARBALL"
fi

# ── 3. Checksum: verify or compute & store ───────────────────────────────────
if [[ -n "${AMAZON_SOURCE_SHA256:-}" ]]; then
  # User-supplied expected hash → strict verify
  ACTUAL="$(sha256sum "$TARBALL" | awk '{print $1}')"
  if [[ "$ACTUAL" != "$AMAZON_SOURCE_SHA256" ]]; then
    echo "ERROR: SHA-256 mismatch!"
    echo "  expected: $AMAZON_SOURCE_SHA256"
    echo "  actual:   $ACTUAL"
    echo "Delete $TARBALL and re-run to re-download."
    exit 1
  fi
  echo "Checksum OK (verified against AMAZON_SOURCE_SHA256)"
  # Write/update the stored file
  echo "$AMAZON_SOURCE_SHA256  $(basename "$TARBALL")" > "$SHA256_FILE"
elif [[ -f "$SHA256_FILE" ]]; then
  # Stored hash from a previous run → verify for corruption
  echo "Verifying checksum from $SHA256_FILE ..."
  # sha256sum -c expects "hash  filename" with filename relative to cwd
  (cd "$DOWNLOADS" && sha256sum -c "$(basename "$SHA256_FILE")")
  echo "Checksum OK"
else
  # First run, no expected hash → compute and store
  ACTUAL="$(sha256sum "$TARBALL" | awk '{print $1}')"
  echo "$ACTUAL  $(basename "$TARBALL")" > "$SHA256_FILE"
  echo "Checksum stored: $ACTUAL"
  echo "NOTE: No authoritative hash provided. Future runs will verify against this computed value."
  echo "      Set AMAZON_SOURCE_SHA256 to an official hash if/when Amazon publishes one."
fi

# ── 4. Extract into upstream (idempotent) ────────────────────────────────────
SENTINEL="$UPSTREAM/.extracted"
TARBALL_NAME="$(basename "$TARBALL")"

if [[ -f "$SENTINEL" && "$(cat "$SENTINEL")" == "$TARBALL_NAME" && "$FORCE_EXTRACT" -eq 0 ]]; then
  echo "Upstream already extracted from $TARBALL_NAME — skipping."
  echo "Use --force-extract to re-extract."
else
  if [[ "$FORCE_EXTRACT" -eq 1 && -f "$SENTINEL" ]]; then
    echo "Force-extract requested; clearing $UPSTREAM ..."
    # Remove extracted contents but not the dir itself (keep .gitkeep)
    find "$UPSTREAM" -mindepth 1 -not -name '.gitkeep' -delete
  fi
  echo "Extracting $TARBALL → $UPSTREAM ..."
  # ponytail: -xjf for .tar.bz2; was -xzf (.tar.gz) — fixed to match Amazon tarball format
  tar -xjf "$TARBALL" -C "$UPSTREAM"
  echo "$TARBALL_NAME" > "$SENTINEL"
  echo "Extraction complete. upstream is read-only source-of-truth — do not modify."
fi

# ── 5. Stage vendored trees into CM12 source tree ───────────────────────────
DEVICE_TREE="$REPO_ROOT/workspace/device/amazon/biscuit"
if [[ -d "$REPO_ROOT/workspace/cm12/build" ]]; then
  "$REPO_ROOT/workspace/scripts/stage-tree.sh"
else
  echo "CM12 source not synced yet — skipping stage-tree."
  echo "After 'repo sync', re-run preflight.sh."
fi

echo ""
echo "Preflight done."
echo "  downloads: $DOWNLOADS"
echo "  upstream:  $UPSTREAM"
echo "  device tree: $DEVICE_TREE"
echo "Next: workspace/scripts/build.sh"
