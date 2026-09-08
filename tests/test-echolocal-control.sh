#!/usr/bin/env bash
# Exercise the root-ADB EchoLocal control script without a device.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/device/amazon/biscuit/rootdir/echolocal.sh"
[[ -f "$SOURCE" ]] || { echo "missing: $SOURCE" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
root="$tmp/fs"
mkdir -p "$root/system/bin" "$root/system/xbin" \
    "$root/data/misc/echolocal" "$root/data/misc/wifi/sockets"

python3 - "$SOURCE" "$tmp/echolocal" "$root" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()
source = source.replace('#!/system/bin/sh', '#!/usr/bin/env bash', 1)
root = sys.argv[3]
source = source.replace('/system/', root + '/system/').replace('/data/', root + '/data/')
pathlib.Path(sys.argv[2]).write_text(source)
PY
chmod 0755 "$tmp/echolocal"

cat > "$root/system/xbin/busybox" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    dd)
        count_file="$ECHOLOCAL_TEST_ROOT/dd-count"
        count=0
        [[ ! -f "$count_file" ]] || count="$(cat "$count_file")"
        count=$((count + 1))
        printf '%s\n' "$count" > "$count_file"
        if [[ "$count" == 1 ]]; then
            printf '01234567890123456789012345678901'
        else
            printf 'abcdefghijklmnopqrstuvwxyzABCDEF'
        fi
        ;;
    wc) exec /usr/bin/wc "${@:2}" ;;
    *) exit 2 ;;
esac
EOF
cat > "$root/system/xbin/base64" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/base64 "$@"
EOF
cat > "$root/system/xbin/awk" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/awk "$@"
EOF
cat > "$root/system/xbin/tr" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/tr "$@"
EOF
cat > "$root/system/xbin/od" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/od "$@"
EOF
cat > "$root/system/xbin/stty" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$root/system/xbin/id" <<'EOF'
#!/usr/bin/env bash
printf 'uid=0(root) gid=0(root)\n'
EOF
cat > "$root/system/xbin/chown" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$root/system/xbin/setprop" <<'EOF'
#!/usr/bin/env bash
printf '%s=%s\n' "$1" "$2" >> "$ECHOLOCAL_TEST_ROOT/setprop.log"
EOF
cat > "$root/system/xbin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$root/system/bin/wpa_passphrase" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
IFS= read -r passphrase
printf '%s\n' "${#passphrase}" >> "$ECHOLOCAL_TEST_ROOT/passphrase-lengths"
printf 'network={\n\t#psk=hidden\n\tpsk=%064d\n}\n' 0
EOF
cat > "$root/system/bin/wpa_cli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
shift 2
command="$1"
shift
printf '%s %s\n' "$command" "$*" >> "$ECHOLOCAL_TEST_ROOT/wpa.log"
case "$command" in
    list_networks)
        printf 'network id / ssid / bssid / flags\n'
        printf '4\t%s\tany\t[CURRENT]\n' "$ECHOLOCAL_TEST_TARGET"
        ;;
    add_network) printf '7\n' ;;
    status) cat "$ECHOLOCAL_TEST_ROOT/status" ;;
    set_network|enable_network|select_network|save_config|remove_network) printf 'OK\n' ;;
    *) printf 'FAIL\n'; exit 1 ;;
esac
EOF
chmod 0755 "$root/system/xbin"/* "$root/system/bin"/*

export ECHOLOCAL_TEST_ROOT="$root"
export PATH="$root/system/xbin:/usr/bin:/bin"
run() { bash "$tmp/echolocal" "$@"; }

run key ensure
key="$(cat "$root/data/misc/echolocal/psk")"
[[ ${#key} -eq 44 ]]
[[ "$(stat -c %a "$root/data/misc/echolocal/psk")" == 600 ]]
[[ "$(run key show)" == "$key" ]]
run key ensure
[[ "$(cat "$root/data/misc/echolocal/psk")" == "$key" ]]
rotated="$(run key rotate 2>"$tmp/rotate.err")"
[[ "$rotated" != "$key" ]]
grep -Fxq 'ctl.restart=ledcontroller' "$root/setprop.log"

export ECHOLOCAL_TEST_TARGET='Cafe Network'
printf 'wpa_state=COMPLETED\nssid=Cafe Network\nip_address=192.0.2.10\n' > "$root/status"
python3 - "$tmp/echolocal" "$root" <<'PY'
import os
import pty
import subprocess
import sys

script, root = sys.argv[1:]
master, slave = pty.openpty()
env = os.environ.copy()
process = subprocess.Popen(
    ['bash', script, 'wifi', 'connect', 'Cafe Network'],
    stdin=slave,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=env,
)
os.close(slave)
os.write(master, b'testpassphrase\n')
out, err = process.communicate(timeout=10)
os.close(master)
if process.returncode:
    raise SystemExit(f'connect failed: {out!r} {err!r}')
if 'connected: Cafe Network (192.0.2.10)' not in out:
    raise SystemExit(f'unexpected connect output: {out!r}')
PY
grep -Fxq '14' "$root/passphrase-lengths"
grep -Fq 'remove_network 4' "$root/wpa.log"
grep -Fq 'set_network 7 ssid 43616665204e6574776f726b' "$root/wpa.log"
grep -Eq '^set_network 7 psk [0-9a-f]{64}$' "$root/wpa.log"
! grep -Fq 'testpassphrase' "$root/wpa.log"
grep -Fxq 'ctl.restart=dhcpcd_wlan0' "$root/setprop.log"

: > "$root/wpa.log"
export ECHOLOCAL_TEST_TARGET='Open Network'
printf 'wpa_state=COMPLETED\nssid=Open Network\nip_address=192.0.2.11\n' > "$root/status"
run wifi open 'Open Network' > "$tmp/open.out"
grep -Fq 'set_network 7 key_mgmt NONE' "$root/wpa.log"
grep -Fq 'connected: Open Network (192.0.2.11)' "$tmp/open.out"

echo 'EchoLocal control checks passed'
