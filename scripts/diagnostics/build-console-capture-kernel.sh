#!/usr/bin/env bash
# Build an isolated ARM64 capture kernel; never stage it into a ROM or access USB.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$ROOT/workspace/diagnostics/cm12-console-capture-build"
CONTAINER=cm12-biscuit-build
IMAGE=biscuit-kernel-builder:latest

if [[ "${1:-}" != --inside-container ]]; then
  running=$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)
  [[ "$running" != true ]] || { echo "ERROR: $CONTAINER is running; refusing to replace it." >&2; exit 1; }
  docker image inspect "$IMAGE" >/dev/null
  if [[ -n "$running" ]]; then docker rm "$CONTAINER" >/dev/null; fi
  docker run -d --name "$CONTAINER" --user "$(id -u):$(id -g)" \
    -v "$ROOT:$ROOT" -w "$ROOT" "$IMAGE" \
    bash scripts/diagnostics/build-console-capture-kernel.sh --inside-container
  echo "Monitor: docker logs -f $CONTAINER"
  echo "Output (not installed): $BUILD/out/arch/arm64/boot/Image.gz-dtb"
  exit
fi

SRC="$BUILD/src"
OUT="$BUILD/out"
KERNEL_STAGE="$SRC" bash "$ROOT/scripts/stage-kernel-for-build.sh"
# Only the disposable stage is patched. Reserve before buddy/CMA allocation.
[[ "$(grep -Fxc $'\tearly_init_fdt_scan_reserved_mem();' "$SRC/arch/arm64/mm/init.c")" == 1 ]] || {
  echo 'ERROR: Expected exactly one early RAM-reservation anchor.' >&2; exit 1;
}
sed -i '/^\tearly_init_fdt_scan_reserved_mem();$/a\
\
\t/* Diagnostic capture: do not reuse the previous ARM32 console buffer. */\
\tmemblock_reserve(0x44400000, 0x10000);' "$SRC/arch/arm64/mm/init.c"
cp "$ROOT/scripts/diagnostics/fireos6-console-reader.c" "$SRC/drivers/misc/biscuit_fireos6_console.c"
printf '\nobj-y += biscuit_fireos6_console.o\n' >> "$SRC/drivers/misc/Makefile"
mkdir -p "$OUT"
args=(-C "$SRC" "O=$OUT" ARCH=arm64 CROSS_COMPILE=/toolchain/aarch64-linux-android-4.9/bin/aarch64-linux-android-)
make "${args[@]}" biscuit_defconfig
if [[ -f "$SRC/arch/arm64/configs/trapz.config" ]]; then
  cat "$SRC/arch/arm64/configs/trapz.config" >> "$OUT/.config"
fi
# Otherwise this kernel would overwrite the evidence before the reader starts.
grep -qx 'CONFIG_MTK_RAM_CONSOLE=y' "$OUT/.config"
sed -i 's/^CONFIG_MTK_RAM_CONSOLE=y$/# CONFIG_MTK_RAM_CONSOLE is not set/' "$OUT/.config"
make "${args[@]}" oldconfig </dev/null
grep -qx '# CONFIG_MTK_RAM_CONSOLE is not set' "$OUT/.config"
make "${args[@]}" headers_install
cp -a "$SRC/amazon-build/prebuilt/." "$OUT/"
make "${args[@]}" -j8
sha256sum "$OUT/arch/arm64/boot/Image.gz-dtb"
echo 'PASS: isolated capture kernel built; no device or ROM staging operations.'
