#!/usr/bin/env bash
# Verify a pinned CA input produces reproducible outputs and stages from a clean tree.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ARCHIVE="$TMP/cacerts.tar.gz"

python3 - "$ARCHIVE" <<'PY'
import io
import sys
import tarfile

with tarfile.open(sys.argv[1], "w:gz") as tar:
    for name, data in (("files/12345678.0", b"CERT-A\n"), ("files/abcdef01.1", b"CERT-B\n")):
        info = tarfile.TarInfo(name)
        info.size = len(data)
        tar.addfile(info, io.BytesIO(data))
PY
ARCHIVE_URL="$(python3 - "$ARCHIVE" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).as_uri())
PY
)"

if "$REPO_ROOT/scripts/update-ca-certs.sh" refs/heads/main >/dev/null 2>&1; then
  echo 'mutable CA ref unexpectedly accepted' >&2
  exit 1
fi
if CA_CERTS_TEST_ARCHIVE_URL="$ARCHIVE_URL" "$REPO_ROOT/scripts/update-ca-certs.sh" >/dev/null 2>&1; then
  echo 'test CA archive unexpectedly accepted outside test mode' >&2
  exit 1
fi

DUPLICATE_ARCHIVE="$TMP/duplicate-cacerts.tar.gz"
python3 - "$DUPLICATE_ARCHIVE" <<'PY'
import io
import sys
import tarfile

with tarfile.open(sys.argv[1], "w:gz") as tar:
    for name in ("files/12345678.0", "other/12345678.0"):
        data = b"CERT\n"
        info = tarfile.TarInfo(name)
        info.size = len(data)
        tar.addfile(info, io.BytesIO(data))
PY
DUPLICATE_URL="$(python3 - "$DUPLICATE_ARCHIVE" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).as_uri())
PY
)"
if CA_CERTS_TEST_MODE=1 CA_CERTS_TEST_ARCHIVE_URL="$DUPLICATE_URL" \
  CA_CERTS_OUT="$TMP/duplicate" CA_CERTS_BUNDLE="$TMP/duplicate.pem" \
  CA_CERTS_METADATA="$TMP/duplicate.source" "$REPO_ROOT/scripts/update-ca-certs.sh" \
  > "$TMP/duplicate.log" 2>&1; then
  echo 'duplicate CA names unexpectedly accepted' >&2
  exit 1
fi
grep -q 'duplicate Android cacert names' "$TMP/duplicate.log"

materialize() {
  local suffix="$1"
  CA_CERTS_TEST_MODE=1 CA_CERTS_TEST_ARCHIVE_URL="$ARCHIVE_URL" \
    CA_CERTS_OUT="$TMP/cacerts-$suffix" \
    CA_CERTS_BUNDLE="$TMP/cacerts-$suffix.pem" \
    CA_CERTS_METADATA="$TMP/cacerts-$suffix.source" \
    "$REPO_ROOT/scripts/update-ca-certs.sh" >/dev/null
}

materialize one
materialize two
cmp "$TMP/cacerts-one.pem" "$TMP/cacerts-two.pem"
diff -ru "$TMP/cacerts-one" "$TMP/cacerts-two"
cmp "$TMP/cacerts-one.source" "$TMP/cacerts-two.source"
grep -qx 'source_revision=45c7f199cb11b08f6d1ae2b75da25e53140a0c7d' "$TMP/cacerts-one.source"
grep -qx 'certificate_count=2' "$TMP/cacerts-one.source"

mkdir -p "$TMP/cm12/build"
CM12="$TMP/cm12" \
  CA_CERTS_DIR="$TMP/cacerts-one" \
  CA_CERTS_BUNDLE="$TMP/cacerts-one.pem" \
  "$REPO_ROOT/scripts/stage-tree.sh" >/dev/null
cmp "$TMP/cacerts-one/12345678.0" "$TMP/cm12/libcore/luni/src/main/files/cacerts/12345678.0"
cmp "$TMP/cacerts-one.pem" "$TMP/cm12/device/amazon/biscuit/cacerts.pem"

echo 'PASS pinned CA bundle is reproducible and stages from clean inputs'
