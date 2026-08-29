#!/usr/bin/env bash
# Materialize Android CA certs from the reviewed immutable AOSP input.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../config/ca-certificates.env
source "$REPO_ROOT/config/ca-certificates.env"

[[ $# -eq 0 ]] || { echo "Usage: $0" >&2; exit 2; }
[[ "$AOSP_CA_REVISION" =~ ^[0-9a-f]{40}$ ]] || {
  echo "ERROR: AOSP_CA_REVISION must be a 40-character commit SHA" >&2
  exit 1
}

CA_CERTS_OUT="${CA_CERTS_OUT:-$REPO_ROOT/workspace/cacerts}"
CA_CERTS_BUNDLE="${CA_CERTS_BUNDLE:-$REPO_ROOT/workspace/cacerts.pem}"
CA_CERTS_METADATA="${CA_CERTS_METADATA:-$REPO_ROOT/workspace/cacerts.source}"
ARCHIVE_URL="${CA_CERTS_TEST_ARCHIVE_URL:-$AOSP_CA_PROJECT/+archive/$AOSP_CA_REVISION/$AOSP_CA_DIRECTORY.tar.gz}"

if [[ "${CA_CERTS_TEST_MODE:-0}" != 1 ]]; then
  [[ "$CA_CERTS_OUT" == "$REPO_ROOT/workspace/cacerts" ]] || {
    echo "ERROR: CA_CERTS_OUT is test-only" >&2
    exit 1
  }
  [[ "$CA_CERTS_BUNDLE" == "$REPO_ROOT/workspace/cacerts.pem" ]] || {
    echo "ERROR: CA_CERTS_BUNDLE is test-only" >&2
    exit 1
  }
  [[ "$CA_CERTS_METADATA" == "$REPO_ROOT/workspace/cacerts.source" ]] || {
    echo "ERROR: CA_CERTS_METADATA is test-only" >&2
    exit 1
  }
  [[ -z "${CA_CERTS_TEST_ARCHIVE_URL:-}" ]] || {
    echo "ERROR: CA_CERTS_TEST_ARCHIVE_URL requires CA_CERTS_TEST_MODE=1" >&2
    exit 1
  }
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/biscuit-cacerts.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
python3 - "$ARCHIVE_URL" "$AOSP_CA_PROJECT" "$AOSP_CA_REVISION" "$AOSP_CA_DIRECTORY" \
  "$TMP/cacerts" "$TMP/cacerts.pem" "$TMP/cacerts.source" <<'PY'
import hashlib
import io
import re
import sys
import tarfile
import urllib.request
from pathlib import Path

url, project, revision, directory, out, bundle, metadata = sys.argv[1:]
out, bundle, metadata = Path(out), Path(bundle), Path(metadata)
with urllib.request.urlopen(url, timeout=60) as response:
    archive = response.read()

certs = []
with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
    for member in tar.getmembers():
        name = Path(member.name).name
        if member.isfile() and re.match(r"^[0-9a-f]{8}\.\d+$", name):
            src = tar.extractfile(member)
            if src is not None:
                certs.append((name, src.read()))
if not certs:
    raise SystemExit(f"no Android cacerts found in {url}")
if len({name for name, _ in certs}) != len(certs):
    raise SystemExit(f"duplicate Android cacert names in {url}")

out.mkdir()
with bundle.open("wb") as bundle_file:
    for name, data in sorted(certs):
        (out / name).write_bytes(data)
        bundle_file.write(data.rstrip() + b"\n")
metadata.write_text(
    f"source_project={project}\n"
    f"source_revision={revision}\n"
    f"source_directory={directory}\n"
    f"archive_sha256={hashlib.sha256(archive).hexdigest()}\n"
    f"bundle_sha256={hashlib.sha256(bundle.read_bytes()).hexdigest()}\n"
    f"certificate_count={len(certs)}\n"
)
print(f"WROTE {len(certs)} certs from {revision} to {out}")
print(f"WROTE curl CA bundle to {bundle}")
PY

rm -rf "$CA_CERTS_OUT"
mkdir -p "$(dirname "$CA_CERTS_OUT")" "$(dirname "$CA_CERTS_BUNDLE")" "$(dirname "$CA_CERTS_METADATA")"
mv "$TMP/cacerts" "$CA_CERTS_OUT"
mv "$TMP/cacerts.pem" "$CA_CERTS_BUNDLE"
mv "$TMP/cacerts.source" "$CA_CERTS_METADATA"
printf 'WROTE CA source metadata to %s\n' "$CA_CERTS_METADATA"
