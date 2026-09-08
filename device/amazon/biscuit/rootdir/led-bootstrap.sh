#!/system/bin/sh
# Stop the kernel boot animation, show green briefly, then leave the ring off.
set -eu

boot=/sys/bus/i2c/devices/0-003f/boot_animation
frame=/sys/bus/i2c/devices/0-003f/frame
green=00ff0000ff0000ff0000ff0000ff0000ff0000ff0000ff0000ff0000ff0000ff0000ff00
black=000000000000000000000000000000000000000000000000000000000000000000000000

attempts=0
while [ ! -e "$boot" ] || [ ! -e "$frame" ]; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 10 ]; then
        echo 'LED ring did not become ready' >&2
        exit 1
    fi
    sleep 1
done

printf 0 > "$boot"
printf '%s' "$green" > "$frame"
sleep 1
printf '%s' "$black" > "$frame"
