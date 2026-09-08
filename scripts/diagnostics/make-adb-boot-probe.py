#!/usr/bin/env python3
"""Offline ADB-only boot probes: no block mounts, recovery UI, or device access."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "workspace/diagnostics/cm14-adb-boot-probe"
INPUTS = {
    "cm12-control": ("workspace/cm12/out-docker/target/product/biscuit/boot.img",
                     "b11776078f5ccbd37ff212285c0ad6520b2363b822f451e74b4b376f1507f079"),
    "fireos6-mtk": ("workspace/diagnostics/cm14-mtk-kernel-header-test/boot.img",
                    "5cd16e1f41d74e9e68cff0822a6b084953f9a6d91c09fc7844a551424f19744e"),
    "fireos6-stock": ("workspace/diagnostics/cm14-fstab-runtime-test/boot.test.img",
                      "b1bdbaa081ea439466c2bb4430468f0dd41f7c09a362b4c78bc98c4851ff1ab3"),
    "recovery-ramdisk": ("workspace/cm12/out-docker/target/product/biscuit/ramdisk-recovery.img",
                         "656681286dfb5111e3181e6bee548a970780c7c2f8a7a0d76c99ae45fcc681fe"),
    "installer": ("workspace/diagnostics/cm14-fstab-runtime-test/boot-fstab-test.zip",
                  "200a869a3f632943a490a717cc254550eb5eff897e396a912f158925b28831a9"),
}
INIT_RC = b"""# Diagnostic userspace only: never mount or modify block devices.
on early-init
    write /sys/fs/selinux/checkreqprot 0
    setcon u:r:init:s0
    start ueventd

on init
    export PATH /sbin:/system/bin
    export ANDROID_ROOT /system
    export ANDROID_DATA /data
    mount tmpfs tmpfs /tmp

on late-init
    trigger fs
    trigger boot

on fs
    mkdir /dev/usb-ffs 0770 shell shell
    mkdir /dev/usb-ffs/adb 0770 shell shell
    mount functionfs adb /dev/usb-ffs/adb uid=2000,gid=2000
    write /sys/class/android_usb/android0/enable 0
    write /sys/class/android_usb/android0/idVendor 18D1
    write /sys/class/android_usb/android0/idProduct D001
    write /sys/class/android_usb/android0/f_ffs/aliases adb
    write /sys/class/android_usb/android0/functions adb
    write /sys/class/android_usb/android0/iManufacturer Biscuit
    write /sys/class/android_usb/android0/iProduct BootProbe
    write /sys/class/android_usb/android0/iSerial ${ro.serialno}

on boot
    setprop service.adb.root 1
    start adbd
    write /sys/class/android_usb/android0/enable 1

on property:sys.powerctl=*
    powerctl ${sys.powerctl}

service ueventd /sbin/ueventd
    seclabel u:r:ueventd:s0

service adbd /sbin/adbd --root_seclabel=u:r:su:s0 --device_banner=device
    disabled
    socket adbd stream 660 system system
    seclabel u:r:adbd:s0
"""
PROPS = b"""ro.secure=0
ro.debuggable=1
ro.adb.secure=1
ro.product.device=biscuit
ro.product.name=biscuit
ro.product.model=Biscuit_Boot_Probe
ro.product.manufacturer=Biscuit
ro.biscuit.bootprobe=adb-only-v1
"""


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unpack_boot(data):
    assert data[:8] == b"ANDROID!"
    f = struct.unpack_from("<9I", data, 8)
    assert f[7] == 2048
    offset, parts = 2048, []
    for size in (f[0], f[2], f[4], f[8]):
        assert offset + size <= len(data)
        parts.append(data[offset:offset + size])
        offset += (size + 2047) // 2048 * 2048
    assert offset == len(data)
    return data[:2048], parts


def boot_id(parts):
    digest = hashlib.sha1()
    for part in parts:
        digest.update(part)
        digest.update(struct.pack("<I", len(part)))
    return digest.digest() + bytes(12)


def unpack_cpio(raw):
    entries, offset = {}, 0
    while True:
        assert raw[offset:offset + 6] == b"070701"
        fields = [int(raw[offset + i:offset + i + 8], 16) for i in range(6, 110, 8)]
        size, namesize = fields[6], fields[11]
        assert namesize > 0
        name_end = offset + 110 + namesize
        assert raw[name_end - 1] == 0
        name = raw[offset + 110:name_end - 1].decode()
        start = (name_end + 3) & ~3
        end = start + size
        assert end <= len(raw)
        if name == "TRAILER!!!":
            return entries
        assert name not in entries
        entries[name] = (fields[1], raw[start:end])
        offset = (end + 3) & ~3


def pack_cpio(entries):
    result = bytearray()
    for inode, (name, (mode, data)) in enumerate(
            [*sorted(entries.items()), ("TRAILER!!!", (0, b""))], 1):
        name = name.encode() + b"\0"
        fields = (inode, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(name), 0)
        result += b"070701" + b"".join(f"{f:08x}".encode() for f in fields) + name
        result += bytes((-len(result)) % 4)
        result += data
        result += bytes((-len(result)) % 4)
    result += bytes((-len(result)) % 512)
    return bytes(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--entry-beacon", action="store_true",
                        help="Include the stock entry probe; requires the assembled beacon section")
    beacon = None
    if parser.parse_args().entry_beacon:
        section = (OUT / "arm32-entry-beacon/beacon.section.bin").read_bytes()
        # Exact ARM instructions from arm32-entry-beacon.S, including its test-only return.
        assert section == struct.pack("<9I", 0xe30f3ff0, 0xe3443440, 0xe3a044a5,
                                      0xe5834000, 0xe5831004, 0xe5832008,
                                      0xe10f4000, 0xe583400c, 0xe12fff1e)
        beacon = section[:32]
    inputs = {}
    for name, (path, expected) in INPUTS.items():
        inputs[name] = (ROOT / path).read_bytes()
        assert sha(inputs[name]) == expected, f"Changed input: {path}"
    source = unpack_cpio(gzip.decompress(inputs["recovery-ramdisk"]))
    keep = ("init", "sbin/adbd", "sbin/recovery", "sepolicy", "file_contexts",
            "property_contexts", "service_contexts", "seapp_contexts", "selinux_version",
            "ueventd.rc", "ueventd.mt8163.rc")
    entries = {name: source[name] for name in keep}
    for name in ("init", "sbin/adbd", "sbin/recovery"):
        data = entries[name][1]
        assert data[:5] == b"\x7fELF\x01" and struct.unpack_from("<H", data, 18)[0] == 40
    for name in ("dev", "proc", "sys", "tmp", "data", "sbin", "system", "system/bin"):
        entries[name] = (0o40755, b"")
    for name, target in {"sbin/ueventd": "../init", "sbin/multi_init": "../init",
                         "system/bin/sh": "/sbin/sh", "sbin/sh": "recovery",
                         "sbin/busybox": "recovery"}.items():
        entries[name] = (0o120777, target.encode())
    key = (Path.home() / ".android/adbkey.pub").read_bytes().strip() + b"\n"
    assert len(key.split()[0]) > 500 and b"PRIVATE KEY" not in key
    entries.update({"init.rc": (0o100644, INIT_RC), "default.prop": (0o100644, PROPS),
                    "adb_keys": (0o100644, key)})
    cpio = pack_cpio(entries)
    assert unpack_cpio(cpio) == entries, "CPIO round-trip failed"
    ramdisk = gzip.compress(cpio, compresslevel=9, mtime=0)
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"inputs": INPUTS, "ramdisk_sha256": sha(ramdisk),
                "adb_public_key_sha256": sha(key), "outputs": {}}
    with zipfile.ZipFile(ROOT / INPUTS["installer"][0]) as installer:
        expected_names = {"boot.img", "META-INF/com/google/android/update-binary",
                          "META-INF/com/google/android/updater-script"}
        assert set(installer.namelist()) == expected_names
        script = installer.read("META-INF/com/google/android/updater-script")
        assert script.count(b"/dev/block/") == 1
        assert b'"/dev/block/platform/soc/by-name/boot_a_x"' in script
        assert b'assert(getprop("ro.boot.slot_suffix") == "_a");' in script
        labels = ["cm12-control", "fireos6-mtk", "fireos6-stock", "fireos6-stock-raw",
                  "fireos6-stock-raw-up"]
        if beacon is not None:
            labels.extend(("fireos6-stock-entry", "fireos6-stock-raw-entry"))
            manifest["entry_beacon"] = {"address": "0x4440fff0", "marker": "0xa5000000",
                                         "sha256": sha(beacon), "bytes": len(beacon)}
        for label in labels:
            base_label = label.removesuffix("-entry").removesuffix("-up")
            header, original = unpack_boot(inputs[base_label.removesuffix("-raw")])
            # CM12 omits the empty DT size from its ID; the diagnostic template includes it.
            counts = [n for n in (3, 4) if header[576:608] == boot_id(original[:n])]
            assert len(counts) == 1, "Unknown boot ID format"
            count = counts[0]
            kernel = original[0]
            if base_label.endswith("-raw"):
                assert struct.unpack_from("<2I", kernel) == (0x58881688, len(kernel) - 512)
                assert kernel[8:40].split(b"\0", 1)[0] == b"KERNEL"
                assert kernel[40:512] == b"\xff" * 472
                kernel = kernel[512:]
                assert struct.unpack_from("<I", kernel, 0x24)[0] == 0x016f2818
            if label.endswith("-entry"):
                entry_offset = 0 if base_label.endswith("-raw") else 512
                if entry_offset:
                    assert struct.unpack_from("<2I", kernel) == (0x58881688, len(kernel) - 512)
                pristine = kernel
                assert kernel[entry_offset:entry_offset + 32] == struct.pack("<I", 0xe1a00000) * 8
                assert struct.unpack_from("<I", kernel, entry_offset + 0x24)[0] == 0x016f2818
                kernel = kernel[:entry_offset] + beacon + kernel[entry_offset + 32:]
                assert (kernel[:entry_offset] + struct.pack("<I", 0xe1a00000) * 8
                        + kernel[entry_offset + 32:]) == pristine
            cmdline = header[64:576]
            if label.endswith("-up"):
                args = cmdline.split(b"\0", 1)[0]
                assert b"maxcpus=" not in args
                args += b" maxcpus=1"
                assert len(args) < 512
                cmdline = args.ljust(512, b"\0")
            parts = original.copy()
            parts[0], parts[1] = kernel, ramdisk
            patched = bytearray(header)
            struct.pack_into("<I", patched, 8, len(kernel))
            struct.pack_into("<I", patched, 16, len(ramdisk))
            patched[64:576] = cmdline
            patched[576:608] = boot_id(parts[:count])
            image = bytes(patched) + b"".join(p + bytes((-len(p)) % 2048) for p in parts)
            h, verified = unpack_boot(image)
            assert verified == parts and h[576:608] == boot_id(verified[:count])
            assert h[:8] == header[:8] and h[12:16] == header[12:16]
            assert h[20:64] == header[20:64] and h[64:576] == cmdline
            assert h[608:] == header[608:]
            assert len(image) <= 16777216
            assert verified[0] == kernel and verified[2:] == original[2:]
            (OUT / f"{label}.boot.img").write_bytes(image)
            output = OUT / f"{label}.zip"
            with zipfile.ZipFile(output, "w") as package:
                for info in installer.infolist():
                    package.writestr(info, image if info.filename == "boot.img"
                                     else installer.read(info.filename))
            with zipfile.ZipFile(output) as package:
                assert package.testzip() is None and package.read("boot.img") == image
                assert package.read("META-INF/com/google/android/updater-script") == script
            manifest["outputs"][label] = {"bytes": len(image), "boot_sha256": sha(image),
                                          "zip_sha256": sha(output.read_bytes())}
            print(label, manifest["outputs"][label])
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("PASS: CPIO/boot-ID/ZIP checks; identical ARM32 ADB-only ramdisk in all probes.")
    print("Device operations: none. Output:", OUT)


if __name__ == "__main__":
    main()
