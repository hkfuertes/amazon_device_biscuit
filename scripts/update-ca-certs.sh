#!/usr/bin/env bash
# Download Android CA certs from AOSP and build curl's PEM bundle.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF="${1:-refs/heads/main}"
PROJECT="https://android.googlesource.com/platform/system/ca-certificates"
DIR="files"
OUT="$REPO_ROOT/workspace/cacerts"
BUNDLE="$REPO_ROOT/workspace/cacerts.pem"

mkdir -p "$OUT"
find "$OUT" -maxdepth 1 -type f ! -name README.md -delete
: > "$BUNDLE"

python3 - "$PROJECT" "$REF" "$DIR" "$OUT" "$BUNDLE" <<'PY'
import io, re, sys, tarfile, urllib.parse, urllib.request
from pathlib import Path

project, ref, directory, out, bundle = sys.argv[1], sys.argv[2], sys.argv[3], Path(sys.argv[4]), Path(sys.argv[5])
url = f"{project}/+archive/{urllib.parse.quote(ref, safe='/')}/{directory}.tar.gz"
with urllib.request.urlopen(url, timeout=60) as r:
    data = r.read()

certs = []
with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tar:
    for member in tar.getmembers():
        name = Path(member.name).name
        if member.isfile() and re.match(r'^[0-9a-f]{8}\.\d+$', name):
            src = tar.extractfile(member)
            if src is not None:
                certs.append((name, src.read()))
if not certs:
    raise SystemExit(f'no Android cacerts found in {url}')

with bundle.open('wb') as b:
    for name, data in sorted(certs):
        (out / name).write_bytes(data)
        b.write(data.rstrip() + b'\n')
print(f'WROTE {len(certs)} certs from {url} to {out}')
print(f'WROTE curl CA bundle to {bundle}')
PY
