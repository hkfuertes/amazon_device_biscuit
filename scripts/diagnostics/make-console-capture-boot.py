#!/usr/bin/env python3
"""Package the isolated capture kernel with the already validated ADB-only ramdisk."""
import hashlib
import io
import json
from pathlib import Path
import runpy
import struct
import zlib
import zipfile

ROOT = Path(__file__).resolve().parents[2]
D = ROOT / "workspace/diagnostics/cm14-adb-boot-probe"
BUILD = ROOT / "workspace/diagnostics/cm12-console-capture-build/out"
helpers = runpy.run_path(str(ROOT / "scripts/diagnostics/make-adb-boot-probe.py"))
unpack_boot, boot_id = helpers["unpack_boot"], helpers["boot_id"]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    template = (D / "cm12-control.boot.img").read_bytes()
    assert sha(template) == "01ac44805e20299a772ce3f6540f9d5051d4f81091d0ed5b202df8e348075cb8"
    config = (BUILD / ".config").read_bytes()
    assert b"# CONFIG_MTK_RAM_CONSOLE is not set\n" in config
    kernel = (BUILD / "arch/arm64/boot/Image.gz-dtb").read_bytes()
    assert kernel[:3] == b"\x1f\x8b\x08"
    decoder = zlib.decompressobj(31)
    flat = decoder.decompress(kernel)
    assert decoder.eof and decoder.unused_data.startswith(b"\xd0\x0d\xfe\xed")
    assert flat[56:60] == b"ARM\x64"
    assert b"[DEBUG-biscuit-ramconsole] read-only console reader ready" in flat
    header, original = unpack_boot(template)
    assert header[576:608] == boot_id(original[:3])
    fields = struct.unpack_from("<9I", header, 8)
    assert fields[1] + len(flat) < fields[3], "Kernel overlaps ramdisk"
    assert fields[3] + len(original[1]) < 0x44400000, "Ramdisk overlaps console"
    parts = original.copy()
    parts[0] = kernel
    changed = bytearray(header)
    struct.pack_into("<I", changed, 8, len(kernel))
    changed[576:608] = boot_id(parts[:3])
    image = bytes(changed) + b"".join(p + bytes((-len(p)) % 2048) for p in parts)
    h, checked = unpack_boot(image)
    assert checked == parts and checked[1:] == original[1:]
    assert h[576:608] == boot_id(checked[:3])
    assert h[:8] == header[:8] and h[12:576] == header[12:576] and h[608:] == header[608:]
    assert len(image) <= 16777216
    output = D / "cm12-console-capture.boot.img"
    output.write_bytes(image)
    installer = (D / "cm12-control.zip").read_bytes()
    assert sha(installer) == "9d96cded39b964325d78e0f703773dd8a83ccc410591b68d837aa5a6732c7c6b"
    package_path = D / "cm12-console-capture.zip"
    names = {"boot.img", "META-INF/com/google/android/update-binary",
             "META-INF/com/google/android/updater-script"}
    with zipfile.ZipFile(io.BytesIO(installer)) as source:
        assert len(source.infolist()) == 3 and set(source.namelist()) == names
        assert source.read("boot.img") == template
        metadata = {name: source.read(name) for name in names - {"boot.img"}}
        with zipfile.ZipFile(package_path, "w") as package:
            for entry in source.infolist():
                package.writestr(entry, image if entry.filename == "boot.img" else metadata[entry.filename])
    with zipfile.ZipFile(package_path) as package:
        assert package.testzip() is None and set(package.namelist()) == names
        assert package.read("boot.img") == image
        assert all(package.read(name) == data for name, data in metadata.items())
    manifest = {"template_sha256": sha(template), "config_sha256": sha(config),
                "kernel_sha256": sha(kernel), "boot_sha256": sha(image),
                "boot_bytes": len(image), "zip_sha256": sha(package_path.read_bytes()),
                "console_address": "0x44400000",
                "console_bytes": 65536, "device_operations": "none"}
    (D / "cm12-console-capture.manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("PASS: boot ID/components/load ranges verified; no device operations.")
    print(output)
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
