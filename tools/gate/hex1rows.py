"""Hex1 rows. Comparisons live in the judges. A missing program is an observation."""

import hashlib
import os
import shutil
import struct
import threading

from tools.gate import drive
from tools.gate.observe import (
    CommentDisasm, Expect, Hex1Calls, Hex1Size, Observation, SameHash, prove,
)

BAD = (
    ("label-digit.hex1", "empty"),
    ("label-hash.hex1", "empty"),
    ("label-semi.hex1", "empty"),
    ("label-colon.hex1", "empty"),
    ("label-percent.hex1", "empty"),
    ("label-space.hex1", "empty"),
    ("label-lf.hex1", "empty"),
    ("label-low.hex1", "empty"),
    ("label-percent-digit.hex1", "empty"),
    ("label-digit-after.hex1", "one"),
)


def program_path(gate):
    return os.path.join(gate.root, "out", "hex1")


def tests_of(gate):
    return os.path.join(gate.root, "ladder/1-hex1/tests")


def run_hex1(gate, argv, out_path):
    program = program_path(gate)
    if not os.path.isfile(program):
        return Observation(status=None, out_exists=False)
    return gate.run([program, *argv], out_path=out_path)


def hex0_fixture_names(gate):
    base = os.path.join(gate.root, "ladder/0-hex0/tests")
    names = []
    for name in os.listdir(base):
        if name.endswith(".hex0"):
            names.append(name)
    names.sort()
    return names


def load_hex(path):
    digits = []
    for ch in open(path, encoding="utf-8").read():
        if ch not in " \t\r\n":
            digits.append(ch)
    return bytes.fromhex("".join(digits))


def ensure_old(gate):
    old = os.path.join(gate.sandbox, "hex1-old")
    if not os.path.exists(old):
        open(old, "wb").write(b"OLDDATA")
        os.chmod(old, 0o640)
    return old


def row_hex1_parity(gate):
    for name in hex0_fixture_names(gate):
        one_parity(gate, name)
    print("row 28: hex1 parity")


def one_parity(gate, name):
    src = os.path.join(gate.root, "ladder/0-hex0/tests", name)
    out0 = os.path.join(gate.sandbox, "h0-" + name)
    out1 = os.path.join(gate.sandbox, "h1-" + name)
    got0 = gate.run([gate.seed, src, out0], out_path=out0)
    got1 = run_hex1(gate, [src, out1], out1)
    gate.require(
        prove(Expect(
            "row 28 " + name,
            status=got0.status,
            out_exists=got0.out_exists,
            out_bytes=got0.out_bytes,
            out_mode=got0.out_mode,
        ), got1),
        got1,
    )


def row_hex1_labels(gate):
    for name in ("forward.hex1", "backward.hex1", "next.hex1"):
        one_label(gate, name)
    print("row 29: labels")


def one_label(gate, name):
    src = os.path.join(tests_of(gate), name)
    stem = name.split(".", 1)[0]
    want = load_hex(os.path.join(tests_of(gate), stem + ".bytes"))
    out = os.path.join(gate.sandbox, name + ".out")
    obs = run_hex1(gate, [src, out], out)
    gate.require(
        prove(Expect("row 29 " + name, status=0, out_exists=True, out_bytes=want, out_mode=0o755), obs),
        obs,
    )


def row_hex1_bad(gate):
    for name, shape in BAD:
        refuse_shape(gate, name, shape)
    print("row 30: bad label")


def refuse_shape(gate, name, shape):
    src = os.path.join(tests_of(gate), name)
    old = ensure_old(gate)
    absent = os.path.join(gate.sandbox, "h1abs-" + name)
    if os.path.lexists(absent):
        os.remove(absent)
    obs = run_hex1(gate, [src, absent], absent)
    fields = drive.shaped(shape, old, b"A", b"AB")
    gate.require(prove(Expect("row 30 " + name, status=4, **fields), obs), obs)
    pre = os.path.join(gate.sandbox, "h1pre-" + name)
    shutil.copy(old, pre)
    os.chmod(pre, 0o640)
    obs = run_hex1(gate, [src, pre], pre)
    fields = drive.shaped(shape, old, b"A", b"AB")
    gate.require(prove(Expect("row 30 " + name + " pre", status=4, **fields), obs), obs)


def row_hex1_refusals(gate):
    for name, status, body in (
        ("undef.hex1", 8, b""),
        ("undef-after.hex1", 8, b"A"),
        ("twice.hex1", 9, b""),
    ):
        refuse_status(gate, name, status, body)
    refuse_rewind(gate)
    print("row 31: refusals")


def refuse_status(gate, name, status, body):
    src = os.path.join(tests_of(gate), name)
    absent = os.path.join(gate.sandbox, "h1abs-" + name)
    if os.path.lexists(absent):
        os.remove(absent)
    obs = run_hex1(gate, [src, absent], absent)
    gate.require(prove(Expect(
        "row 31 " + name, status=status, out_exists=True, out_bytes=body, out_mode=0o755,
    ), obs), obs)
    pre = os.path.join(gate.sandbox, "h1pre-" + name)
    shutil.copy(ensure_old(gate), pre)
    os.chmod(pre, 0o640)
    obs = run_hex1(gate, [src, pre], pre)
    gate.require(prove(Expect(
        "row 31 " + name + " pre", status=status, out_exists=True, out_bytes=body, out_mode=0o755,
    ), obs), obs)


def refuse_rewind(gate):
    program = program_path(gate)
    if not os.path.isfile(program):
        obs = Observation(status=None, out_exists=False)
        gate.require(prove(Expect(
            "row 31 rewind", status=11, out_exists=True, out_bytes=b"", out_mode=0o755,
        ), obs), obs)
        return
    for kind in ("absent", "existing"):
        obs = rewind_once(gate, program, kind)
        gate.require(prove(Expect(
            "row 31 rewind " + kind, status=11, out_exists=True, out_bytes=b"", out_mode=0o755,
        ), obs), obs)


def rewind_once(gate, program, kind):
    fifo = os.path.join(gate.sandbox, "hex1-fifo-" + kind)
    if os.path.lexists(fifo):
        os.remove(fifo)
    os.mkfifo(fifo)
    out = os.path.join(gate.sandbox, "hex1-fifo-out-" + kind)
    if kind == "existing":
        open(out, "wb").write(b"OLDDATA")
        os.chmod(out, 0o640)
    elif os.path.lexists(out):
        os.remove(out)

    def feed():
        fd = os.open(fifo, os.O_WRONLY)
        os.write(fd, b"41\n")
        os.close(fd)

    thread = threading.Thread(target=feed)
    thread.daemon = True
    thread.start()
    obs = gate.run([program, fifo, out], out_path=out)
    thread.join(1)
    return obs


def row_hex1_self(gate):
    gate.require(prove(SameHash("row 32 self"), self_observation(gate)))
    print("row 32: self-build")


def self_observation(gate):
    built = program_path(gate)
    again = os.path.join(gate.root, "out", "hex1-self")
    built_ok = os.path.isfile(built)
    again_ok = os.path.isfile(again)
    if not built_ok or not again_ok:
        return Observation(before="missing", after="missing-self")
    return Observation(before=file_sha(built), after=file_sha(again))


def file_sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def row_hex1_syscalls(gate):
    gate.require(prove(Hex1Calls(), syscall_observation(gate)))
    print("row 33: syscalls")


def syscall_observation(gate):
    allowed = tuple(drive.tsv_names(os.path.join(
        gate.root, "ladder/1-hex1/x86_64-linux/syscalls.tsv",
    )))
    program = program_path(gate)
    if not os.path.isfile(program):
        return Observation(status=None, names=(), allowed=allowed)
    source = os.path.join(gate.root, "ladder/1-hex1/x86_64-linux/hex1.hex1")
    out = os.path.join(gate.sandbox, "hex1-sys.out")
    trace = os.path.join(gate.sandbox, "hex1-sys.trace")
    obs = gate.run(
        ["strace", "-f", "-o", trace, program, source, out],
        timeout=drive.LONG, out_path=out,
    )
    names = tuple(drive.syscall_names(drive.read_trace(trace)))
    return Observation(status=obs.status, names=names, allowed=allowed)


def row_hex1_disasm(gate):
    gate.require(prove(CommentDisasm("row 34 disasm"), disasm_observation(gate)))
    print("row 34: disasm")


def disasm_observation(gate):
    program = program_path(gate)
    source = os.path.join(gate.root, "ladder/1-hex1/x86_64-linux/hex1.hex0")
    table = os.path.join(gate.root, "ladder/1-hex1/x86_64-linux/gate.tsv")
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


def row_hex1_size(gate):
    obs, want = size_pair(gate)
    gate.require(prove(Hex1Size(want), obs))
    print("row 35: size")


def size_pair(gate):
    path = program_path(gate)
    table = os.path.join(gate.root, "ladder/1-hex1/x86_64-linux/gate.tsv")
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


def row_hex1_lseek(gate):
    lseek_cases(gate)
    print("row 36: lseek fault")


def lseek_cases(gate):
    program = program_path(gate)
    table = os.path.join(gate.root, "ladder/1-hex1/x86_64-linux/gate.tsv")
    calls_path = os.path.join(gate.root, "ladder/1-hex1/x86_64-linux/syscalls.tsv")
    if not os.path.isfile(program) or not os.path.isfile(table):
        miss_lseek(gate)
        return
    facts = drive.tsv_map(table)
    calls = drive.tsv_map(calls_path)
    if "lseek_nth" not in facts or "lseek" not in calls:
        miss_lseek(gate)
        return
    binary = os.path.join(gate.sandbox, "hex1-fault")
    proc = gate.run(
        ["gcc", "-O2", "-o", binary, os.path.join(gate.root, "tools/check/fault.c")],
        timeout=drive.LONG,
    )
    gate.require(prove(Expect("row 36 gcc", status=0), proc), proc)
    src = os.path.join(gate.sandbox, "lseek-in")
    open(src, "wb").write(b"41\n")
    for kind in ("absent", "existing"):
        out = os.path.join(gate.sandbox, "lseek-out-" + kind)
        if kind == "existing":
            open(out, "wb").write(b"OLDDATA")
            os.chmod(out, 0o640)
        elif os.path.lexists(out):
            os.remove(out)
        obs = gate.run(
            [binary, calls["lseek"], "-1", "5", facts["lseek_nth"], program, src, out],
            out_path=out, timeout=drive.LONG,
        )
        gate.require(prove(Expect("row 36 lseek " + kind, status=11), obs), obs)


def miss_lseek(gate):
    obs = Observation(status=None, out_exists=False)
    gate.require(prove(Expect("row 36 lseek", status=11), obs), obs)
