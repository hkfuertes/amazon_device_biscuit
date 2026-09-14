"""Generate legacy recovery OTAs for amonet v2 TWRP's active slot."""

_CURRENT_SLOT_DEVICES = {
    "/system": "/dev/block/current-system",
    "/boot": "/dev/block/current-boot",
}

# CM14's updater property reader sees no device properties in TWRP 3.7 sideload.
_AMONET_SLOT_ASSERTION = (
    'assert(run_program("/sbin/sh", "-c", '
    '"test -x /sbin/amzn_bcbtool || exit 1; '
    'slot=$(/sbin/amzn_bcbtool get_active); '
    'system=$(readlink -f /dev/block/current-system); '
    'boot=$(readlink -f /dev/block/current-boot); '
    'case $slot in '
    'a) test $system = /dev/block/mmcblk0p13 && test $boot = /dev/block/mmcblk0p10 ;; '
    'b) test $system = /dev/block/mmcblk0p14 && test $boot = /dev/block/mmcblk0p11 ;; '
    '*) exit 1 ;; '
    'esac") == "0");'
)


def _replace_default_device_assertion(info):
    """Replace CM14's incompatible property assertion without weakening safety."""
    for index, line in enumerate(info.script.script):
        if line.startswith('assert(getprop("ro.product.device")'):
            info.script.script[index] = _AMONET_SLOT_ASSERTION
            return
    raise ValueError("missing default OTA device assertion")


def _use_current_slot_devices(info):
    """Keep Android's fstab unchanged; alter only generated edify targets."""
    for mount_point, device in _CURRENT_SLOT_DEVICES.items():
        if mount_point not in info.script.fstab:
            raise ValueError("missing %s in OTA fstab" % mount_point)
        info.script.fstab[mount_point].device = device


def FullOTA_Assertions(info):
    _replace_default_device_assertion(info)


def IncrementalOTA_Assertions(info):
    _replace_default_device_assertion(info)


def FullOTA_InstallBegin(info):
    _use_current_slot_devices(info)


def IncrementalOTA_InstallBegin(info):
    _use_current_slot_devices(info)
