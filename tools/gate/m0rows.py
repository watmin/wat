"""M0 rows. Comparisons live in the judges."""

import hashlib
import os
import struct

from tools.gate import drive
from tools.gate.observe import CommentDisasm, Expect, Hex1Calls, Hex1Size, Observation, SameHash, prove


class M0Calls(Hex1Calls):
    reason = "row 48 syscalls"


class M0Size(Hex1Size):
    def __init__(self, want):
        Hex1Size.__init__(self, want)
        self.reason = "row 50 size"


def program_path(gate):
    return os.path.join(gate.root, "out", "m0")


def hex2_path(gate):
    return os.path.join(gate.root, "out", "hex2")


def source_dir(gate):
    return os.path.join(gate.root, "ladder/3-m0/x86_64-linux")


def run_m0(gate, argv, out_path):
    program = program_path(gate)
    if not os.path.isfile(program):
        return Observation(status=None, out_exists=False)
    return gate.run([program, *argv], out_path=out_path)


def file_sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def row_m0_text(gate):
    src = os.path.join(gate.root, "ladder/3-m0/tests/plain.m0")
    text = os.path.join(gate.sandbox, "m0-plain.hex2")
    binary = os.path.join(gate.sandbox, "m0-plain.bin")
    direct = os.path.join(gate.sandbox, "m0-plain.direct")
    obs = run_m0(gate, [src, text], text)
    gate.require(prove(Expect(
        "row 45 plain", status=0, out_exists=True, out_bytes=b"41\n42\n", out_mode=0o755,
    ), obs), obs)
    via = gate.run([hex2_path(gate), text, binary], out_path=binary)
    got = gate.run([hex2_path(gate), src, direct], out_path=direct)
    gate.require(prove(Expect(
        "row 45 assembled", status=got.status, out_exists=got.out_exists,
        out_bytes=got.out_bytes, out_mode=got.out_mode,
    ), via), via)
    define = os.path.join(gate.root, "ladder/3-m0/tests/define-ten.m0")
    out = os.path.join(gate.sandbox, "m0-ten.hex2")
    obs = run_m0(gate, [define, out], out)
    gate.require(prove(Expect(
        "row 45 define", status=0, out_exists=True, out_bytes=b"0A\n", out_mode=0o755,
    ), obs), obs)
    print("row 45: text")


def row_m0_refusals(gate):
    base = os.path.join(gate.root, "ladder/3-m0/tests")
    for name, status in (("dup.m0", 9), ("missing.m0", 4)):
        src = os.path.join(base, name)
        out = os.path.join(gate.sandbox, "m0-" + name)
        obs = run_m0(gate, [src, out], out)
        gate.require(prove(Expect(
            "row 46 " + name, status=status, out_exists=True, out_bytes=b"", out_mode=0o755,
        ), obs), obs)
    print("row 46: refusals")


def row_m0_self(gate):
    gate.require(prove(SameHash("row 47 self"), self_observation(gate)))
    print("row 47: self-build")


def self_observation(gate):
    built = program_path(gate)
    again = os.path.join(gate.root, "out", "m0-self")
    if not os.path.isfile(built) or not os.path.isfile(again):
        return Observation(before="missing", after="missing-self")
    return Observation(before=file_sha(built), after=file_sha(again))


def row_m0_syscalls(gate):
    gate.require(prove(M0Calls(), syscall_observation(gate)))
    print("row 48: syscalls")


def syscall_observation(gate):
    allowed = tuple(drive.tsv_names(os.path.join(source_dir(gate), "syscalls.tsv")))
    program = program_path(gate)
    if not os.path.isfile(program):
        return Observation(status=None, names=(), allowed=allowed)
    src = os.path.join(gate.root, "ladder/3-m0/tests/plain.m0")
    out = os.path.join(gate.sandbox, "m0-sys.out")
    trace = os.path.join(gate.sandbox, "m0-sys.trace")
    obs = gate.run(
        ["strace", "-f", "-o", trace, program, src, out],
        timeout=drive.LONG, out_path=out,
    )
    names = tuple(drive.syscall_names(drive.read_trace(trace)))
    return Observation(status=obs.status, names=names, allowed=allowed)


def row_m0_disasm(gate):
    gate.require(prove(CommentDisasm("row 49 disasm"), disasm_observation(gate)))
    print("row 49: disasm")


def disasm_observation(gate):
    program = program_path(gate)
    source = os.path.join(source_dir(gate), "m0.hex2")
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


def row_m0_size(gate):
    obs, want = size_pair(gate)
    gate.require(prove(M0Size(want), obs))
    print("row 50: size")


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
