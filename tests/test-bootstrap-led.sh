#!/usr/bin/env bash
# Exercise the direct LED boot helper without a device or controller.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export TEST_LED_ROOT="$tmp/fs"
mkdir -p "$TEST_LED_ROOT/sys/bus/i2c/devices/0-003f"
: > "$TEST_LED_ROOT/sys/bus/i2c/devices/0-003f/boot_animation"
: > "$TEST_LED_ROOT/sys/bus/i2c/devices/0-003f/frame"

python3 - "$ROOT/device/amazon/biscuit/rootdir/led-bootstrap.sh" "$tmp/run.sh" "$TEST_LED_ROOT" <<'PY'
import pathlib
import sys
source = pathlib.Path(sys.argv[1]).read_text().replace('/sys/', sys.argv[3] + '/sys/')
pathlib.Path(sys.argv[2]).write_text(source)
PY
sleep() { printf '%s\n' "$1" >> "$tmp/sleeps"; }
export tmp
export -f sleep

bash "$tmp/run.sh"
[[ "$(<"$TEST_LED_ROOT/sys/bus/i2c/devices/0-003f/boot_animation")" == 0 ]]
[[ "$(<"$TEST_LED_ROOT/sys/bus/i2c/devices/0-003f/frame")" == 000000000000000000000000000000000000000000000000000000000000000000000000 ]]
[[ "$(<"$tmp/sleeps")" == 1 ]]

rm "$TEST_LED_ROOT/sys/bus/i2c/devices/0-003f/frame"
: > "$tmp/sleeps"
if bash "$tmp/run.sh" > "$tmp/error" 2>&1; then echo 'accepted missing LED frame' >&2; exit 1; fi
[[ "$(grep -c '^1$' "$tmp/sleeps")" -lt 10 ]]
grep -Fq 'LED ring did not become ready' "$tmp/error"

echo 'bootstrap LED checks passed (no device required)'
