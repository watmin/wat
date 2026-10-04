#!/usr/bin/env python3
"""Fuzz hex0 against a reference written from the contract.

The reference is not hex-check.py. A fixed seed drives the generator.
Most cases decode successfully. The reference states whether OUT exists,
and a missing OUT is None, distinct from an empty file. Bytes are
compared on every status.

Disagreements on the real seed are written under the rung's tests.
Each kind has its own exit code: 3 status, 4 existence, 5 bytes.
A bytes-only disagreement prints the bytes.

--expect-disagree flips the a-f bound in a copy and requires a status
disagreement. --expect-letter-offset flips the letter value offset
(add of the a-f nibble) and requires a disagreement only the byte
comparison can see. Neither flag modifies the seed.
"""

import random
import subprocess
import sys
import tempfile
from pathlib import Path

SEED = 20261004
BOUND = bytes.fromhex("3c0577")
BOUND_FLIPPED = bytes.fromhex("3c0677")
LETTER = bytes.fromhex("040aeb02")
LETTER_FLIPPED = bytes.fromhex("040beb02")
# NEAR: the bytes just outside the digit classes, plus the ends of a byte.
# ':' follows '9', '@' precedes 'A', 'G' follows 'F', '`' precedes 'a',
# 'g' and 'x' follow 'f', '/' precedes '0'.
NEAR = [ord(c) for c in ":@G`gx/"] + [0, 0x7F, 0x80, 0xFF]
REJECT_AFTER = (0x2F, 0x40, 0x80, 0xFF)
ROOT = Path(__file__).resolve().parents[2]


def nibble(byte):
    if 48 <= byte <= 57:
        return byte - 48
    if 65 <= byte <= 70:
        return byte - 55
    if 97 <= byte <= 102:
        return byte - 87
    return None


def reference(data):
    """Return (status, exists, body) for a new OUT.

    exists is False only when OUT must be absent; body is then None.
    An empty file is exists True and body b''. Status 4 and 5 leave the
    bytes decoded before the refusal. This does not model an OUT that
    already existed, nor an open that fails.
    """
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
            return 4, True, bytes(out)
        if pending is None:
            pending = val
        else:
            out.append((pending << 4) | val)
            pending = None
        i += 1
    if pending is not None:
        return 5, True, bytes(out)
    return 0, True, bytes(out)


def digit_char(value, upper):
    if value < 10:
        return chr(48 + value)
    base = 65 if upper else 97
    return chr(base + value - 10)


def encode_byte(value, rng):
    hi = digit_char(value >> 4, rng.randrange(2))
    lo = digit_char(value & 15, rng.randrange(2))
    kind = rng.randrange(5)
    if kind == 1:
        mid = " "
    elif kind == 2:
        mid = "\t"
    elif kind == 3:
        mid = "\r\n"
    elif kind == 4:
        mid = " # n\n"
    else:
        mid = ""
    return hi + mid + lo


def forced():
    yield b""
    yield b"41#\r inside\n42"
    yield b"41#\tinside\n42"
    yield b"41#" + bytes([0xFF]) + b"\n42"
    yield bytes([0x0B])
    yield bytes([0x0C])
    yield b"414"
    yield b"41 4"
    yield b"41\r\n42"
    for value in range(256):
        yield f"{value:02x}".encode()
        yield f"{value:02X}".encode()
        text = f"{value:02x}"
        yield (text[0] + " # c\n" + text[1]).encode()
        yield (text[0] + " " + text[1]).encode()
    for bad in REJECT_AFTER:
        yield b"41" + bytes([ord("4"), bad])
        yield bytes([ord("a"), bad])
    for bad in NEAR:
        yield bytes([bad])
    yield b"4\r\n1"
    yield b"# only comment"
    yield b"4"
    yield b"AA" * 2048


def random_cases(rng, count):
    made = 0
    while made < count:
        if rng.randrange(100) < 85:
            parts = [encode_byte(rng.randrange(256), rng) for _ in range(rng.randrange(1, 9))]
            yield "".join(parts).encode()
        else:
            length = rng.randrange(0, 24)
            raw = bytearray(rng.randrange(256) for _ in range(length))
            if length and rng.randrange(2):
                raw[rng.randrange(length)] = (0x0B, 0x0C, 0x0D)[rng.randrange(3)]
            yield bytes(raw)
        made += 1


def cases(count, rng):
    out = []
    for item in forced():
        out.append(item)
        if len(out) >= count:
            return out
    out.extend(random_cases(rng, count - len(out)))
    return out


def run_one(hex0, data, folder):
    src = folder / "in"
    dst = folder / "out"
    src.write_bytes(data)
    if dst.exists():
        dst.unlink()
    proc = subprocess.run([str(hex0), str(src), str(dst)])
    if dst.exists():
        return proc.returncode, True, dst.read_bytes()
    return proc.returncode, False, None


def flip(blob, old, new):
    found = blob.count(old)
    if found != 1:
        sys.stderr.write("fuzz: pattern found %d times\n" % found)
        sys.exit(2)
    return blob.replace(old, new, 1)


def disagree(got_rc, got_exists, got_body, want_rc, want_exists, want_body):
    if got_rc != want_rc:
        return 3
    if got_exists != want_exists:
        return 4
    if got_body != want_body:
        return 5
    return 0


def main(argv):
    expect = None
    args = []
    for arg in argv:
        if arg == "--expect-disagree":
            expect = "status"
        elif arg == "--expect-letter-offset":
            expect = "letter"
        else:
            args.append(arg)
    if len(args) != 2:
        sys.stderr.write(
            "usage: fuzz-hex0.py [--expect-disagree | --expect-letter-offset] HEX0 COUNT\n"
        )
        return 2
    hex0 = Path(args[0]).resolve()
    count = int(args[1])
    rng = random.Random(SEED)
    sample = cases(count, rng)
    work = Path(tempfile.mkdtemp(prefix="hex0-fuzz-", dir="/var/tmp"))
    target = hex0
    if expect == "status":
        target = work / "mutant"
        target.write_bytes(flip(hex0.read_bytes(), BOUND, BOUND_FLIPPED))
        target.chmod(0o755)
    elif expect == "letter":
        target = work / "mutant"
        target.write_bytes(flip(hex0.read_bytes(), LETTER, LETTER_FLIPPED))
        target.chmod(0o755)
    disagreements = 0
    byte_only = 0
    try:
        for data in sample:
            want_rc, want_exists, want_body = reference(data)
            got_rc, got_exists, got_body = run_one(target, data, work)
            kind = disagree(got_rc, got_exists, got_body, want_rc, want_exists, want_body)
            if kind == 0:
                continue
            disagreements += 1
            if kind == 5:
                byte_only += 1
            if expect:
                continue
            if kind == 5:
                sys.stderr.write(
                    "fuzz: bytes %s vs %s\n"
                    % (
                        got_body.hex() if got_body is not None else "missing",
                        want_body.hex() if want_body is not None else "missing",
                    )
                )
            fixture = ROOT / "ladder/0-hex0/tests/fuzz-disagree.hex0"
            fixture.write_bytes(data)
            sys.stderr.write(
                "fuzz: disagree kind %d status %d vs %d, kept %s\n"
                % (kind, got_rc, want_rc, fixture)
            )
            return kind
    finally:
        for child in work.iterdir():
            child.unlink()
        work.rmdir()
    if expect == "status":
        if disagreements < 1:
            sys.stderr.write("fuzz: flipped seed agreed on every case\n")
            return 1
        sys.stdout.write("fuzz mutant: %d disagreements\n" % disagreements)
        return 0
    if expect == "letter":
        if byte_only < 1:
            sys.stderr.write("fuzz: letter-offset mutant had no byte-only disagreement\n")
            return 1
        sys.stdout.write(
            "fuzz letter-offset mutant: %d disagreements, %d on bytes\n"
            % (disagreements, byte_only)
        )
        return 0
    sys.stdout.write("fuzz: %d agree\n" % count)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
