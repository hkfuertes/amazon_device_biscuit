#!/usr/bin/env bash
# Exercise first-boot state seeding and EchoLocal's rollback hook without a device.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOTSTRAP="$ROOT/device/amazon/biscuit/rootdir/echolocal-bootstrap.sh"
START="$ROOT/device/amazon/biscuit/rootdir/start_animation.sh"
STOP="$ROOT/device/amazon/biscuit/rootdir/stop_animation.sh"
for file in "$BOOTSTRAP" "$START" "$STOP"; do
    [[ -f "$file" ]] || { echo "missing: $file" >&2; exit 1; }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
root="$tmp/fs"
mkdir -p "$root/system/bin" "$root/system/etc/echolocal/models" "$root/data/misc/echolocal/models"

export ECHOLOCAL_TEST_ROOT="$root"
export ECHOLOCAL_TEST_LOG="$tmp/echolocal-args"
cat > "$root/system/bin/echolocal" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ECHOLOCAL_TEST_LOG"
[[ "$*" == 'key ensure' ]]
mkdir -p "$ECHOLOCAL_TEST_ROOT/data/misc/echolocal"
printf '%s\n' 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=' > "$ECHOLOCAL_TEST_ROOT/data/misc/echolocal/psk"
chmod 0600 "$ECHOLOCAL_TEST_ROOT/data/misc/echolocal/psk"
EOF
chmod 0755 "$root/system/bin/echolocal"

cat > "$tmp/expected-start" <<'EOF'
#!/system/bin/sh
# Installed by EchoLocal, replacing a ledctrl call that waits forever on a binder service echod does
# not publish. echod drives the ring instead.
#
# It also puts back the binary an update replaced. echod renames /system/app/echod/echod.prev away once it has run long enough
# to be believed, so finding one here means a boot happened while an update was still on trial.
if [ -f /system/app/echod/echod.prev ]; then
    WAS=$(cat /data/misc/echolocal/updating 2>/dev/null)
    log -t echolocal "rolling back to the previous echod: an update did not settle (${WAS:-unknown})"
    mount -o remount,rw /system
    mv -f /system/app/echod/echod.prev /system/app/echod/echod
    mount -o remount,ro /system
    rm -f /data/misc/echolocal/updating
    setprop echolocal.rolledback "${WAS:-1}"
fi
exit 0
EOF
cat > "$tmp/expected-stop" <<'EOF'
#!/system/bin/sh
# Installed by EchoLocal, replacing a ledctrl call that waits forever on a binder service echod does
# not publish. echod drives the ring instead.
exit 0
EOF
cmp "$tmp/expected-start" "$START"
cmp "$tmp/expected-stop" "$STOP"

python3 - "$BOOTSTRAP" "$tmp/bootstrap.sh" "$START" "$tmp/start_animation.sh" "$root" <<'PY'
import pathlib
import sys

root = sys.argv[5]
for source_path, destination in ((sys.argv[1], sys.argv[2]), (sys.argv[3], sys.argv[4])):
    source = pathlib.Path(source_path).read_text()
    if source.startswith('#!/system/bin/sh'):
        source = source.replace('#!/system/bin/sh', '#!/usr/bin/env bash', 1)
    source = source.replace('/system/', root + '/system/').replace('/data/', root + '/data/')
    pathlib.Path(destination).write_text(source)
PY
cp "$tmp/start_animation.sh" "$root/system/bin/start_animation.sh"
chmod 0755 "$root/system/bin/start_animation.sh"

for model in okay_nabu hey_jarvis hey_mycroft; do
    printf '%s manifest\n' "$model" > "$root/system/etc/echolocal/models/$model.json"
    printf '%s model\n' "$model" > "$root/system/etc/echolocal/models/$model.tflite"
done

setprop() { printf '%s=%s\n' "$1" "$2" >> "$tmp/properties"; }
chown() { :; }
mount() { :; }
log() { :; }
export tmp
export -f setprop chown mount log

bash "$tmp/bootstrap.sh"
for model in okay_nabu hey_jarvis hey_mycroft; do
    cmp "$root/system/etc/echolocal/models/$model.json" "$root/data/misc/echolocal/models/$model.json"
    cmp "$root/system/etc/echolocal/models/$model.tflite" "$root/data/misc/echolocal/models/$model.tflite"
done
grep -Fxq 'ctl.start=ledcontroller' "$tmp/properties"
grep -Fxq 'key ensure' "$tmp/echolocal-args"
[[ -s "$root/data/misc/echolocal/psk" ]]

# The installer contract keeps an existing model pair untouched.
printf 'custom manifest\n' > "$root/data/misc/echolocal/models/okay_nabu.json"
printf 'custom model\n' > "$root/data/misc/echolocal/models/okay_nabu.tflite"
bash "$tmp/bootstrap.sh"
printf 'custom manifest\n' | cmp - "$root/data/misc/echolocal/models/okay_nabu.json"
printf 'custom model\n' | cmp - "$root/data/misc/echolocal/models/okay_nabu.tflite"

# A failed trial is restored before the daemon is started.
mkdir -p "$root/system/app/echod"
printf 'broken\n' > "$root/system/app/echod/echod"
printf 'previous\n' > "$root/system/app/echod/echod.prev"
printf '0.0.6\n' > "$root/data/misc/echolocal/updating"
: > "$tmp/properties"
bash "$root/system/bin/start_animation.sh"
printf 'previous\n' | cmp - "$root/system/app/echod/echod"
[[ ! -e "$root/system/app/echod/echod.prev" ]]
[[ ! -e "$root/data/misc/echolocal/updating" ]]
grep -Fxq 'echolocal.rolledback=0.0.6' "$tmp/properties"
bash "$STOP"

echo 'EchoLocal bootstrap checks passed'
