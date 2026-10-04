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

    reason = "stayed green"

    def accept(self, obs):
        if obs.timed_out or obs.escaped or obs.status in (None, 0):
            return Verdict(False, self.reason)
        return Verdict(True, "")

    def mutants(self, obs):
        return [("status", replace(obs, status=0))]


class NoMutant:
    reason = "no mutant"

    def accept(self, obs):
        return Verdict(True, self.reason)

    def mutants(self, obs):
        return []


def prove(judge, obs):
    """The one loop. A sibling branch is not a proof."""
    real = judge.accept(obs)
    if not real.ok:
        return real
    mutants = judge.mutants(obs)
    if not mutants:
        return Verdict(False, "judge has no mutant")
    for name, mutated in mutants:
        got = judge.accept(mutated)
        if got.ok:
            return Verdict(False, "mutant %s stayed green" % name)
        if judge.reason not in got.reason:
            return Verdict(False, "mutant %s refused without the judge reason" % name)
    return Verdict(True, "")
