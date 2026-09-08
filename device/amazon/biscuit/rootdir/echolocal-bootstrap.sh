#!/system/bin/sh
# Restore a failed EchoLocal trial, seed missing wake words, then hand supervision to init.
set -eu

state=/data/misc/echolocal
models=$state/models
seed=/system/etc/echolocal/models

/system/bin/start_animation.sh
mkdir -p "$models"
chown root:system "$state" "$models"
chmod 0770 "$state" "$models"

for model in okay_nabu hey_jarvis hey_mycroft; do
    if [ ! -f "$models/$model.tflite" ]; then
        cp "$seed/$model.json" "$models/$model.json"
        cp "$seed/$model.tflite" "$models/$model.tflite"
        chown root:system "$models/$model.json" "$models/$model.tflite"
        chmod 0644 "$models/$model.json" "$models/$model.tflite"
    fi
done

setprop ctl.start ledcontroller
