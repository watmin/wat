"""wat0 rows. Comparisons live in the judges."""

import hashlib
import os
import struct

from tools.gate import drive
from tools.gate.observe import CommentDisasm, Expect, Hex1Calls, Hex1Size, Observation, SameHash, prove


class Wat0Calls(Hex1Calls):
    reason = "row 54 syscalls"


class Wat0Size(Hex1Size):
    def __init__(self, want):
        Hex1Size.__init__(self, want)
        self.reason = "row 56 size"


def program_path(gate):
    return os.path.join(gate.root, "out", "wat0")


def source_dir(gate):
    return os.path.join(gate.root, "ladder/4-wat0/x86_64-linux")


def run_wat0(gate, argv, out_path):
    program = program_path(gate)
    if not os.path.isfile(program):
        return Observation(status=None, out_exists=False)
    return gate.run([program, *argv], out_path=out_path)


def file_sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def row_wat0_text(gate):
    root = os.path.join(gate.root, "ladder/4-wat0/tests")
    for name, text in (("forty-two.wat", b"42\n"), ("seven.wat", b"7\n"), ("helper.wat", b"42\n")):
        src = os.path.join(root, name)
        out = os.path.join(gate.sandbox, "wat0-" + name)
        obs = run_wat0(gate, [src, out], out)
        gate.require(prove(Expect(
            "row 51 " + name, status=0, out_exists=True, out_bytes=text, out_mode=0o755,
        ), obs), obs)
    print("row 51: text")


def row_wat0_refusals(gate):
    root = os.path.join(gate.root, "ladder/4-wat0/tests")
    for name, status in (("bad.wat", 4), ("watns.wat", 4), ("dup.wat", 9)):
        src = os.path.join(root, name)
        out = os.path.join(gate.sandbox, "wat0-" + name)
        obs = run_wat0(gate, [src, out], out)
        gate.require(prove(Expect(
            "row 52 " + name, status=status, out_exists=True, out_bytes=b"", out_mode=0o755,
        ), obs), obs)
    print("row 52: refusals")


def row_wat0_self(gate):
    gate.require(prove(SameHash("row 53 self"), self_observation(gate)))
    print("row 53: self-build")


def self_observation(gate):
    built = program_path(gate)
    again = os.path.join(gate.root, "out", "wat0-self")
    if not os.path.isfile(built) or not os.path.isfile(again):
        return Observation(before="missing", after="missing-self")
    return Observation(before=file_sha(built), after=file_sha(again))


def row_wat0_syscalls(gate):
    gate.require(prove(Wat0Calls(), syscall_observation(gate)))
    print("row 54: syscalls")


def syscall_observation(gate):
    allowed = tuple(drive.tsv_names(os.path.join(source_dir(gate), "syscalls.tsv")))
    program = program_path(gate)
    if not os.path.isfile(program):
        return Observation(status=None, names=(), allowed=allowed)
    src = os.path.join(gate.root, "ladder/4-wat0/tests/seven.wat")
    out = os.path.join(gate.sandbox, "wat0-sys.out")
    trace = os.path.join(gate.sandbox, "wat0-sys.trace")
    obs = gate.run(
        ["strace", "-f", "-o", trace, program, src, out],
        timeout=drive.LONG, out_path=out,
    )
    names = tuple(drive.syscall_names(drive.read_trace(trace)))
    return Observation(status=obs.status, names=names, allowed=allowed)


def row_wat0_disasm(gate):
    gate.require(prove(CommentDisasm("row 55 disasm"), disasm_observation(gate)))
    print("row 55: disasm")


def disasm_observation(gate):
    program = program_path(gate)
    source = os.path.join(source_dir(gate), "wat0.hex2")
    table = os.path.join(source_dir(gate), "gate.tsv")
    if not os.path.isfile(program) or not os.path.isfile(source) or not os.path.isfile(table):
        return Observation(status=None, comments=(), insns=())
    facts = drive.tsv_map(table)
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


def row_wat0_size(gate):
    obs, want = size_pair(gate)
    gate.require(prove(Wat0Size(want), obs))
    print("row 56: size")


def size_pair(gate):
    path = program_path(gate)
    table = os.path.join(source_dir(gate), "gate.tsv")
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
    return Observation(
        length=len(data),
        filesz=struct.unpack_from("<Q", data, phoff + 32)[0],
        memsz=struct.unpack_from("<Q", data, phoff + 40)[0],
    ), want
