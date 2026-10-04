#!/usr/bin/env python3
"""Check a hex0 source the way the seed reads bytes.

decode_bytes returns (status, OUT bytes). Status 0, 4 and 5 match hex0:
4 is a byte that is not a digit, a comment, or whitespace, and 5 is an odd
digit count. OUT is the bytes decoded before that refusal. This script
checks. It does not build a rung.
"""

import re
import sys


def nibble(byte):
    if 48 <= byte <= 57:
        return byte - 48
    if 97 <= byte <= 102:
        return byte - 87
    if 65 <= byte <= 70:
        return byte - 55
    return None


def decode_bytes(data):
    """Return (status, bytes). A comment runs to the next LF or end of input."""
    out = bytearray()
    pending = None
    i = 0
    n = len(data)
    while i < n:
        byte = data[i]
        if byte in (35, 59):
            while i < n and data[i] != 10:
                i += 1
            continue
        if byte in (32, 9, 13, 10):
            i += 1
            continue
        val = nibble(byte)
        if val is None:
            return 4, bytes(out)
        if pending is None:
            pending = val
        else:
            out.append((pending << 4) | val)
            pending = None
        i += 1
    if pending is not None:
        return 5, bytes(out)
    return 0, bytes(out)


def digit_text(data):
    """Hex digits only, using the same comment and whitespace rules as decode_bytes."""
    status, _ = decode_bytes(data)
    if status != 0:
        return status, ""
    chars = []
    i = 0
    n = len(data)
    while i < n:
        byte = data[i]
        if byte in (35, 59):
            while i < n and data[i] != 10:
                i += 1
            continue
        if byte in (32, 9, 13, 10):
            i += 1
            continue
        chars.append(chr(byte))
        i += 1
    return 0, "".join(chars)


def lint_bytes(data):
    """Line numbers whose code carries a hex digit and no comment."""
    bare = []
    start = 0
    lineno = 1
    n = len(data)
    while start <= n:
        end = data.find(b"\n", start)
        if end < 0:
            line = data[start:]
            next_start = n + 1
        else:
            line = data[start:end]
            next_start = end + 1
        cut = len(line)
        for j, byte in enumerate(line):
            if byte in (35, 59):
                cut = j
                break
        body = line[:cut]
        if re.search(br"[0-9A-Fa-f]", body) and cut == len(line):
            bare.append(lineno)
        if end < 0:
            break
        lineno += 1
        start = next_start
    return bare


def main(argv):
    mode = "decode"
    args = []
    for arg in argv:
        if arg == "--lint":
            mode = "lint"
        elif arg == "--digits":
            mode = "digits"
        else:
            args.append(arg)
    if len(args) != 1:
        sys.stderr.write("usage: hex-check.py [--lint | --digits] FILE\n")
        return 2
    data = open(args[0], "rb").read()
    if mode == "lint":
        bare = lint_bytes(data)
        if bare:
            for lineno in bare:
                sys.stdout.write("lint: bare line %d\n" % lineno)
            return 1
        sys.stdout.write("lint: ok\n")
        return 0
    if mode == "digits":
        status, text = digit_text(data)
        if status != 0:
            sys.stderr.write("hex-check: status %d\n" % status)
            return status
        sys.stdout.write(text)
        return 0
    status, out = decode_bytes(data)
    sys.stdout.buffer.write(out)
    if status != 0:
        sys.stderr.write("hex-check: status %d\n" % status)
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
