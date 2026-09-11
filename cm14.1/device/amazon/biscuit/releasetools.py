"""Generate legacy recovery OTAs for amonet v2 TWRP's active slot."""

_CURRENT_SLOT_DEVICES = {
    "/system": "/dev/block/current-system",
    "/boot": "/dev/block/current-boot",
}


def _use_current_slot_devices(info):
    """Keep Android's fstab unchanged; alter only generated edify targets."""
    for mount_point, device in _CURRENT_SLOT_DEVICES.items():
        if mount_point not in info.script.fstab:
            raise ValueError("missing %s in OTA fstab" % mount_point)
        info.script.fstab[mount_point].device = device


def FullOTA_InstallBegin(info):
    _use_current_slot_devices(info)


def IncrementalOTA_InstallBegin(info):
    _use_current_slot_devices(info)
