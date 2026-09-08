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
