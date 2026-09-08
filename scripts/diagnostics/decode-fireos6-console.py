#!/usr/bin/env python3
"""Validate/decode one 64-KiB MTK RAM-console dump; never access a device."""
import hashlib
from pathlib import Path
import struct
import sys

SIZE = 65536
MAGIC = 0x43474244


def decode(data):
    if len(data) != SIZE:
        raise ValueError("Expected an exact 64-KiB RAM-console buffer")
    h = struct.unpack_from("<16I", data)
    offset, start, used, capacity = h[12:16]
    if h[0] != MAGIC or h[10] != SIZE:
        raise ValueError("Unrecognized RAM-console header")
    if not (64 <= offset < SIZE and 0 < capacity <= SIZE - offset):
        raise ValueError("Console extent is outside the buffer")
    if not (0 <= start <= used <= capacity):
        raise ValueError("Invalid circular-buffer indices")
    ring = data[offset:offset + capacity]
    # Same order as ram_console_lastk_show(): tail first, then wrapped prefix.
    return ring[start:used] + ring[:start]


def self_test():
    raw = bytearray(SIZE)
    header = [0] * 16
    header[0], header[10] = MAGIC, SIZE
    header[12:16] = [SIZE - 4, 3, 3, 4]
    struct.pack_into("<16I", raw, 0, *header)
    raw[-4:] = b"abc\0"
    assert decode(raw) == b"abc"
    header[13:15] = [2, 4]
    struct.pack_into("<16I", raw, 0, *header)
    raw[-4:] = b"cdab"
    assert decode(raw) == b"abcd"
    for invalid in (raw[:-1], bytes(SIZE)):
        try:
            decode(invalid)
        except ValueError:
            pass
        else:
            raise AssertionError("Invalid buffer accepted")
    header[13:15] = [4, 1]
    struct.pack_into("<16I", raw, 0, *header)
    try:
        decode(raw)
    except ValueError:
        pass
    else:
        raise AssertionError("Invalid cursor accepted")


if __name__ == "__main__":
    self_test()
    if len(sys.argv) != 2:
        raise SystemExit("Usage: decode-fireos6-console.py --self-test | <raw-buffer>")
    if sys.argv[1] == "--self-test":
        print("PASS: partial/wrapped buffers and malformed-input rejection.")
    else:
        source = Path(sys.argv[1])
        data = source.read_bytes()
        log = decode(data)
        output = Path(str(source) + ".console.log")
        output.write_bytes(log)
        print("Validated buffer SHA-256:", hashlib.sha256(data).hexdigest())
        print("Decoded bytes:", len(log), "Output:", output)
