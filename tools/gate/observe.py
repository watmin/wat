"""Judges are pure functions of an expectation and an observation."""

from dataclasses import dataclass, replace


@dataclass(frozen=True)
class Observation:
    status: int | None = None
    out_exists: bool | None = None
    out_bytes: bytes | None = None
    out_mode: int | None = None
    stdout: bytes = b""
    stderr: bytes = b""
    timed_out: bool = False
    escaped: tuple = ()
    names: tuple = ()
    allowed: tuple = ()
    length: int | None = None
    filesz: int | None = None
    memsz: int | None = None
    insns: tuple = ()
    comments: tuple = ()
    bare: tuple = ()
    nonascii: tuple = ()
    before: str | None = None
    after: str | None = None
    digest: str = ""
    prior_mode: int | None = None
    ref_status: int | None = None
    ref_out: bytes | None = None
    check_status: int | None = None
    check_out: bytes | None = None
    code: int | None = None
    left: int = 0
    children: int = 0
    always_ok: bool = False
    empty_ok: bool = False
    empty_reason: str = ""
    hits: tuple = ()
    bad_hits: tuple = ()
    good_hits: tuple = ()
    static_hits: tuple = ()
    shown: bytes = b""
    blob: bytes = b""
    cr_status: int = 0


@dataclass(frozen=True)
class Verdict:
    ok: bool
    reason: str


@dataclass(frozen=True)
class Expect:
    """Accept only this observation shape. Mutants are the real observation, bent."""

    reason: str
    status: int | None = None
    out_exists: bool | None = None
    out_bytes: bytes | None = None
    out_mode: int | None = None
    timed_out: bool = False
    allow_escape: bool = False
    stdout_has: bytes | None = None
    stderr_has: bytes | None = None

    def accept(self, obs):
        if obs.timed_out != self.timed_out:
            return Verdict(False, self.reason)
        if not self.allow_escape and obs.escaped:
            return Verdict(False, self.reason)
        if self.status is not None and obs.status != self.status:
            return Verdict(False, self.reason)
        if self.out_exists is not None and obs.out_exists != self.out_exists:
            return Verdict(False, self.reason)
        if self.out_bytes is not None and obs.out_bytes != self.out_bytes:
            return Verdict(False, self.reason)
        if self.out_mode is not None and obs.out_mode != self.out_mode:
            return Verdict(False, self.reason)
        if self.stdout_has is not None and self.stdout_has not in obs.stdout:
            return Verdict(False, self.reason)
        if self.stderr_has is not None and self.stderr_has not in obs.stderr:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        bent = []
        if self.status is not None:
            bent.append(("status", replace(obs, status=(obs.status or 0) + 1)))
        if self.out_bytes is not None and obs.out_bytes:
            flipped = bytearray(obs.out_bytes)
            flipped[0] ^= 0x01
            bent.append(("byte", replace(obs, out_bytes=bytes(flipped))))
        if self.out_exists is not None:
            bent.append(("exists", replace(obs, out_exists=not obs.out_exists, out_bytes=b"" if not obs.out_exists else None)))
        if self.out_mode is not None:
            bent.append(("mode", replace(obs, out_mode=0o644)))
        bent.append(("timeout", replace(obs, timed_out=not obs.timed_out)))
        if self.stdout_has is not None:
            bent.append(("stdout", replace(obs, stdout=b"")))
        if self.stderr_has is not None:
            bent.append(("stderr", replace(obs, stderr=b"")))
        return bent


class Always:
    """A judge that accepts every observation. The prover must refuse it."""

    reason = "always"

    def accept(self, obs):
        return Verdict(True, "")

    def mutants(self, obs):
        return [("status", replace(obs, status=(obs.status or 0) + 1))]


class Nonzero:
    """Accept a red child. Status 0 is the mutant."""

    def __init__(self, reason="stayed green"):
        self.reason = reason

    def accept(self, obs):
        if obs.timed_out != False:
            return Verdict(False, self.reason)
        if len(obs.escaped) != 0:
            return Verdict(False, self.reason)
        if obs.status in (None, 0):
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [("status", replace(obs, status=0))]


class ProverCheck:
    """Row 0: an always-accept judge is refused, and a judge with no mutant is refused."""

    reason = "row 0 prover"

    def accept(self, obs):
        if obs.always_ok != False:
            return Verdict(False, self.reason)
        if obs.empty_ok != False:
            return Verdict(False, self.reason)
        if "no mutant" not in obs.empty_reason:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [
            ("always", replace(obs, always_ok=True)),
            ("empty", replace(obs, empty_ok=True)),
            ("reason", replace(obs, empty_reason="other")),
        ]


class Syscalls:
    reason = "row 8 syscalls"

    def accept(self, obs):
        names = obs.names
        extra = tuple(name for name in names if name not in obs.allowed and name != "execve")
        missing = tuple(name for name in obs.allowed if name not in names)
        if obs.status != 0:
            return Verdict(False, self.reason)
        if names[:1] != ("execve",):
            return Verdict(False, self.reason)
        if names.count("execve") != 1:
            return Verdict(False, self.reason)
        if len(extra) != 0:
            return Verdict(False, self.reason)
        if len(missing) != 0:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        names = obs.names
        return [
            ("extra", replace(obs, names=names + ("openat",))),
            ("missing", replace(obs, names=tuple(name for name in names if name != "read"))),
            ("execve", replace(obs, names=("execve",) + names)),
        ]


class Disasm:
    reason = "row 9 disasm"

    def accept(self, obs):
        if obs.status != 0:
            return Verdict(False, self.reason)
        if len(obs.comments) != 156:
            return Verdict(False, self.reason)
        if len(obs.insns) != len(obs.comments):
            return Verdict(False, self.reason)
        for left, right in zip(obs.comments, obs.insns):
            if left != right:
                return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        def bend(part, value):
            row = list(obs.insns[0])
            row[part] = value
            insns = list(obs.insns)
            insns[0] = tuple(row)
            return tuple(insns)

        first = obs.insns[0]
        return [
            ("offset", replace(obs, insns=bend(0, first[0] + 1))),
            ("bytes", replace(obs, insns=bend(1, first[1] + b"\x90"))),
            ("text", replace(obs, insns=bend(2, first[2] + " x"))),
        ]


class Size:
    def __init__(self, want):
        self.want = want
        self.reason = "row 10 size"

    def accept(self, obs):
        if obs.length != self.want:
            return Verdict(False, self.reason)
        if obs.filesz != obs.length:
            return Verdict(False, self.reason)
        if obs.memsz != obs.length:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [
            ("length", replace(obs, length=obs.length + 1)),
            ("filesz", replace(obs, filesz=obs.filesz + 1)),
            ("memsz", replace(obs, memsz=obs.memsz + 1)),
        ]


class Lint:
    reason = "row 11 lint"

    def accept(self, obs):
        if len(obs.bare) != 0:
            return Verdict(False, self.reason)
        if len(obs.nonascii) != 0:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [
            ("bare", replace(obs, bare=(1,))),
            ("nonascii", replace(obs, nonascii=(0,))),
        ]


class FuzzAgree:
    reason = "row 12 fuzz"

    def accept(self, obs):
        if obs.ref_status != obs.check_status:
            return Verdict(False, self.reason)
        if obs.ref_out != obs.check_out:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [("status", replace(obs, check_status=(obs.check_status or 0) + 1))]


class FifoMode:
    reason = "row 7 fifo"

    def accept(self, obs):
        if obs.status != 3:
            return Verdict(False, self.reason)
        if obs.prior_mode != obs.out_mode:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [
            ("status", replace(obs, status=0)),
            ("mode", replace(obs, out_mode=(obs.prior_mode or 0) ^ 1)),
        ]


class TruncOrder:
    reason = "row 13 trunc"

    def accept(self, obs):
        if obs.status != 3:
            return Verdict(False, self.reason)
        if obs.out_mode != 0o640:
            return Verdict(False, self.reason)
        if obs.out_bytes == b"OLDDATA":
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [
            ("status", replace(obs, status=0)),
            ("mode", replace(obs, out_mode=0o644)),
            ("bytes", replace(obs, out_bytes=b"OLDDATA")),
        ]


class Digest:
    def __init__(self, want):
        self.want = want
        self.reason = "row 19 sha256"

    def accept(self, obs):
        if obs.digest != self.want:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        last = obs.digest[-1:]
        flip = "0" if last != "0" else "1"
        return [("digest", replace(obs, digest=obs.digest[:-1] + flip))]


class SameHash:
    def __init__(self, reason):
        self.reason = reason

    def accept(self, obs):
        if obs.before is None:
            return Verdict(False, self.reason)
        if obs.before != obs.after:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [("changed", replace(obs, after=(obs.after or "") + "x"))]


class ChangedHash:
    def __init__(self, reason):
        self.reason = reason

    def accept(self, obs):
        if obs.before is None:
            return Verdict(False, self.reason)
        if obs.after is None:
            return Verdict(False, self.reason)
        if obs.before == obs.after:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [("same", replace(obs, after=obs.before))]


class TestsText:
    reason = "row 22 tests text"

    def accept(self, obs):
        if obs.shown == obs.blob:
            if obs.cr_status == 0:
                return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [("same", replace(obs, shown=obs.blob, cr_status=0))]


class Signals:
    def __init__(self, name):
        self.reason = "row 24 %s" % name

    def accept(self, obs):
        if obs.code is None:
            return Verdict(False, self.reason)
        if obs.code == 0:
            return Verdict(False, self.reason)
        if obs.left != 0:
            return Verdict(False, self.reason)
        if obs.children != 0:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [
            ("code", replace(obs, code=0)),
            ("left", replace(obs, left=1)),
            ("children", replace(obs, children=1)),
        ]


class AstLint:
    reason = "row 26 ast"

    def accept(self, obs):
        if len(obs.hits) != 0:
            return Verdict(False, self.reason)
        if len(obs.good_hits) != 0:
            return Verdict(False, self.reason)
        if len(obs.bad_hits) == 0:
            return Verdict(False, self.reason)
        if len(obs.static_hits) == 0:
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [
            ("hits", replace(obs, hits=("x",))),
            ("bad", replace(obs, bad_hits=())),
            ("good", replace(obs, good_hits=("x",))),
            ("static", replace(obs, static_hits=())),
        ]


class NoMutant:
    reason = "no mutant"

    def accept(self, obs):
        return Verdict(True, self.reason)

    def mutants(self, obs):
        return []


def _named(judge, text):
    if judge.reason in text:
        return text
    return "%s: %s" % (judge.reason, text)


def prove(judge, obs):
    """The one loop. A sibling branch is not a proof."""
    real = judge.accept(obs)
    if not real.ok:
        return real
    mutants = judge.mutants(obs)
    if not mutants:
        return Verdict(False, _named(judge, "judge has no mutant"))
    for name, mutated in mutants:
        got = judge.accept(mutated)
        if got.ok:
            return Verdict(False, _named(judge, "mutant %s stayed green" % name))
        if judge.reason not in got.reason:
            return Verdict(False, _named(judge, "mutant %s refused without the judge reason" % name))
    return Verdict(True, "")
