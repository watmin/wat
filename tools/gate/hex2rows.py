"""Hex2 rows. Comparisons live in the judges. A missing program is an observation."""

import hashlib
import os
import shutil
import struct

from tools.gate import drive
from tools.gate.observe import (
    CommentDisasm, Expect, Hex1Calls, Hex1Size, Observation, SameHash, prove,
)


class Hex2Calls(Hex1Calls):
    reason = "row 41 syscalls"


class Hex2Size(Hex1Size):
    def __init__(self, want):
        Hex1Size.__init__(self, want)
        self.reason = "row 43 size"


WIDTHS = (
    ("rel1-zero.hex2", 0, b"\x00A"),
    ("rel1-max.hex2", 0, bytes([0x7F]) + b"\x00" * 127),
    ("rel1-min.hex2", 0, b"\x00" * 127 + b"\x80"),
    ("rel1-over.hex2", 10, b""),
    ("rel1-under.hex2", 10, b"\x00" * 128),
    ("rel2-zero.hex2", 0, b"\x00\x00A"),
    ("abs-four.hex2", 0, b"\x04\x00\x40\x00A"),
    ("abs-base.hex2", 0, b"\x00\x00\x40\x00"),
    ("abs-undef.hex2", 8, b""),
    ("label-amp.hex2", 0, b"\xfc\xff\xff\xffA"),
)

BAD = (
    ("bad-width-0.hex2", b""),
    ("bad-width-3.hex2", b""),
    ("bad-width-a.hex2", b""),
    ("bad-width-A.hex2", b""),
    ("bad-width-after.hex2", b"A"),
    ("bad-amp.hex2", b""),
)


def program_path(gate):
    return os.path.join(gate.root, "out", "hex2")


def hex1_path(gate):
    return os.path.join(gate.root, "out", "hex1")


def tests_of(gate):
    return os.path.join(gate.root, "ladder/2-hex2/tests")


def run_prog(gate, program, argv, out_path):
    if not os.path.isfile(program):
        return Observation(status=None, out_exists=False)
    return gate.run([program, *argv], out_path=out_path)


def file_sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def names_under(root, suffix):
    names = []
    for name in os.listdir(root):
        if name.endswith(suffix):
            names.append(name)
    names.sort()
    return names


def row_hex2_parity(gate):
    pairs = (
        ("ladder/0-hex0/tests", ".hex0"),
        ("ladder/1-hex1/tests", ".hex1"),
    )
    for folder, suffix in pairs:
        base = os.path.join(gate.root, folder)
        for name in names_under(base, suffix):
            one_parity(gate, os.path.join(base, name), name)
    print("row 37: hex2 parity")


def one_parity(gate, src, name):
    out1 = os.path.join(gate.sandbox, "h1-" + name)
    out2 = os.path.join(gate.sandbox, "h2-" + name)
    got1 = run_prog(gate, hex1_path(gate), [src, out1], out1)
    got2 = run_prog(gate, program_path(gate), [src, out2], out2)
    gate.require(
        prove(Expect(
            "row 37 " + name,
            status=got1.status,
            out_exists=got1.out_exists,
            out_bytes=got1.out_bytes,
            out_mode=got1.out_mode,
        ), got2),
        got2,
    )


def row_hex2_widths(gate):
    for name, status, body in WIDTHS:
        one_width(gate, name, status, body)
    one_text(gate, "row 38 rel2-min", sixteen(32766), 0, b"\x00" * 32766 + b"\x00\x80")
    one_text(gate, "row 38 rel2-under", sixteen(32767), 10, b"\x00" * 32767)
    print("row 38: widths")


def sixteen(count):
    return ":L\n" + ("00\n" * count) + "%2L\n"


def one_width(gate, name, status, body):
    src = os.path.join(tests_of(gate), name)
    both(gate, "row 38 " + name, src, status, body)


def one_text(gate, reason, text, status, body):
    src = os.path.join(gate.sandbox, reason.replace(" ", "-") + ".hex2")
    open(src, "w", encoding="utf-8").write(text)
    both(gate, reason, src, status, body)


def both(gate, reason, src, status, body):
    absent = os.path.join(gate.sandbox, "h2abs-" + reason.replace(" ", "-"))
    if os.path.lexists(absent):
        os.remove(absent)
    obs = run_prog(gate, program_path(gate), [src, absent], absent)
    gate.require(prove(Expect(
        reason, status=status, out_exists=True, out_bytes=body, out_mode=0o755,
    ), obs), obs)
    pre = os.path.join(gate.sandbox, "h2pre-" + reason.replace(" ", "-"))
    old = os.path.join(gate.sandbox, "hex2-old")
    if not os.path.exists(old):
        open(old, "wb").write(b"OLDDATA")
        os.chmod(old, 0o640)
    shutil.copy(old, pre)
    os.chmod(pre, 0o640)
    obs = run_prog(gate, program_path(gate), [src, pre], pre)
    gate.require(prove(Expect(
        reason + " pre", status=status, out_exists=True, out_bytes=body, out_mode=0o755,
    ), obs), obs)


def row_hex2_bad(gate):
    for name, body in BAD:
        src = os.path.join(tests_of(gate), name)
        both(gate, "row 39 " + name, src, 4, body)
    print("row 39: bad width")


def row_hex2_self(gate):
    gate.require(prove(SameHash("row 40 self"), self_observation(gate)))
    print("row 40: self-build")


def self_observation(gate):
    built = program_path(gate)
    again = os.path.join(gate.root, "out", "hex2-self")
    if not os.path.isfile(built) or not os.path.isfile(again):
        return Observation(before="missing", after="missing-self")
    return Observation(before=file_sha(built), after=file_sha(again))


def row_hex2_syscalls(gate):
    gate.require(prove(Hex2Calls(), syscall_observation(gate)))
    print("row 41: syscalls")


def syscall_observation(gate):
    allowed = tuple(drive.tsv_names(os.path.join(
        gate.root, "ladder/2-hex2/x86_64-linux/syscalls.tsv",
    )))
    program = program_path(gate)
    if not os.path.isfile(program):
        return Observation(status=None, names=(), allowed=allowed)
    source = os.path.join(gate.root, "ladder/2-hex2/x86_64-linux/hex2.hex2")
    out = os.path.join(gate.sandbox, "hex2-sys.out")
    trace = os.path.join(gate.sandbox, "hex2-sys.trace")
    obs = gate.run(
        ["strace", "-f", "-o", trace, program, source, out],
        timeout=drive.LONG, out_path=out,
    )
    names = tuple(drive.syscall_names(drive.read_trace(trace)))
    return Observation(status=obs.status, names=names, allowed=allowed)


def row_hex2_disasm(gate):
    gate.require(prove(CommentDisasm("row 42 disasm"), disasm_observation(gate)))
    print("row 42: disasm")


def disasm_observation(gate):
    program = program_path(gate)
    source = os.path.join(gate.root, "ladder/2-hex2/x86_64-linux/hex2.hex1")
    table = os.path.join(gate.root, "ladder/2-hex2/x86_64-linux/gate.tsv")
    if not os.path.isfile(program) or not os.path.isfile(source) or not os.path.isfile(table):
        return Observation(status=None, comments=(), insns=())
    facts = drive.tsv_map(table)
    needed = ("objdump_machine", "insn_width", "code_base", "size")
    for key in needed:
        if key not in facts:
            return Observation(status=None, comments=(), insns=())
    proc = gate.run([
        "objdump", "-D", "-b", "binary", "-m", facts["objdump_machine"],
        "--start-address", hex(int(facts["code_base"])),
        "--stop-address", hex(int(facts["size"])),
        "--insn-width", facts["insn_width"], program,
    ], timeout=drive.LONG)
    return Observation(
        status=proc.status,
        insns=drive.dumped_triples(proc.stdout.decode("utf-8", "replace")),
        comments=tuple(drive.comment_triples(source)),
    )


def row_hex2_size(gate):
    obs, want = size_pair(gate)
    gate.require(prove(Hex2Size(want), obs))
    print("row 43: size")


def size_pair(gate):
    path = program_path(gate)
    table = os.path.join(gate.root, "ladder/2-hex2/x86_64-linux/gate.tsv")
    missing = Observation(length=-1, filesz=-1, memsz=-1)
    if not os.path.isfile(path) or not os.path.isfile(table):
        return missing, 0
    facts = drive.tsv_map(table)
    if "size" not in facts:
        return missing, 0
    want = int(facts["size"])
    data = open(path, "rb").read()
    if len(data) < 64 or data[:4] != b"\x7fELF":
        return Observation(length=len(data), filesz=-1, memsz=-1), want
    phoff = struct.unpack_from("<Q", data, 32)[0]
    filesz = struct.unpack_from("<Q", data, phoff + 32)[0]
    memsz = struct.unpack_from("<Q", data, phoff + 40)[0]
    return Observation(length=len(data), filesz=filesz, memsz=memsz), want


def row_hex2_lseek(gate):
    lseek_cases(gate)
    print("row 44: lseek fault")


def lseek_cases(gate):
    program = program_path(gate)
    table = os.path.join(gate.root, "ladder/2-hex2/x86_64-linux/gate.tsv")
    calls_path = os.path.join(gate.root, "ladder/2-hex2/x86_64-linux/syscalls.tsv")
    if not os.path.isfile(program) or not os.path.isfile(table):
        miss = Observation(status=None, out_exists=False)
        gate.require(prove(Expect("row 44 lseek", status=11), miss), miss)
        return
    facts = drive.tsv_map(table)
    calls = drive.tsv_map(calls_path)
    binary = os.path.join(gate.sandbox, "hex2-fault")
    proc = gate.run(
        ["gcc", "-O2", "-o", binary, os.path.join(gate.root, "tools/check/fault.c")],
        timeout=drive.LONG,
    )
    gate.require(prove(Expect("row 44 gcc", status=0), proc), proc)
    src = os.path.join(gate.sandbox, "hex2-lseek-in")
    open(src, "wb").write(b"41\n")
    for kind in ("absent", "existing"):
        out = os.path.join(gate.sandbox, "hex2-lseek-out-" + kind)
        if kind == "existing":
            open(out, "wb").write(b"OLDDATA")
            os.chmod(out, 0o640)
        elif os.path.lexists(out):
            os.remove(out)
        obs = gate.run(
            [binary, calls["lseek"], "-1", "5", facts["lseek_nth"], program, src, out],
            out_path=out, timeout=drive.LONG,
        )
        gate.require(prove(Expect("row 44 lseek " + kind, status=11), obs), obs)
