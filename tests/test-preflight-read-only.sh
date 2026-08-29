#!/usr/bin/env bash
# Verify preflight accepts complete pinned inputs and writes nothing.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE="$TMP/repo"
mkdir -p "$FAKE/scripts" "$FAKE/config" "$FAKE/manifest" "$FAKE/bin" \
  "$FAKE/device/amazon/biscuit" "$FAKE/device/amazon/mt8163-common" \
  "$FAKE/hardware/amazon" "$FAKE/hardware/mediatek" "$FAKE/patches" "$FAKE/docker" \
  "$FAKE/workspace/cm12/build" \
  "$FAKE/workspace/kernel/amazon/biscuit/arch/arm64/configs" \
  "$FAKE/workspace/extracted/biscuit-stock-272.6.4.1" \
  "$FAKE/workspace/vendor/amazon/mt8163-common" "$FAKE/workspace/vendor/amazon/biscuit" \
  "$FAKE/workspace/device/amazon/biscuit/prebuilt" "$FAKE/workspace/cacerts"
cp "$REPO_ROOT/scripts/preflight.sh" "$FAKE/scripts/"
cp "$REPO_ROOT/config/ca-certificates.env" "$FAKE/config/"
touch "$FAKE/manifest/cm12.lock.xml" \
  "$FAKE/workspace/kernel/amazon/biscuit/arch/arm64/configs/biscuit_defconfig" \
  "$FAKE/workspace/extracted/biscuit-stock-272.6.4.1/system.img" \
  "$FAKE/workspace/vendor/amazon/mt8163-common/mt8163-common-vendor.mk" \
  "$FAKE/workspace/vendor/amazon/mt8163-common/BoardConfigVendor.mk" \
  "$FAKE/workspace/vendor/amazon/biscuit/biscuit-vendor.mk" \
  "$FAKE/workspace/device/amazon/biscuit/prebuilt/kernel"
printf 'certificate\n' > "$FAKE/workspace/cacerts/12345678.0"
cp "$FAKE/workspace/cacerts/12345678.0" "$FAKE/workspace/cacerts.pem"
printf 'source_revision=45c7f199cb11b08f6d1ae2b75da25e53140a0c7d\n' > "$FAKE/workspace/cacerts.source"
printf 'bundle_sha256=%s\n' "$(sha256sum "$FAKE/workspace/cacerts.pem" | awk '{ print $1 }')" >> "$FAKE/workspace/cacerts.source"
printf 'certificate_count=1\n' >> "$FAKE/workspace/cacerts.source"
for command in docker 7z; do
  printf '#!/usr/bin/env sh\nexit 0\n' > "$FAKE/bin/$command"
  chmod +x "$FAKE/bin/$command"
done

snapshot() {
  (cd "$FAKE" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum)
}
before="$(snapshot)"
PATH="$FAKE/bin:$PATH" "$FAKE/scripts/preflight.sh" > "$TMP/preflight.log"
after="$(snapshot)"
[[ "$before" == "$after" ]]
grep -qx 'Preflight OK.' "$TMP/preflight.log"

echo 'PASS preflight accepts pinned CA inputs without writes'
