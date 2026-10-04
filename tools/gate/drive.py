"""The driver calls rows. Comparisons live in judges."""

import hashlib
import importlib.util
import os
import random
import shutil
import signal
import struct
import subprocess
import sys
import tempfile

from tools.gate import layout
from tools.gate.fuzzref import reference
from tools.gate.lint_rows import lint_file, lint_gate, mutant_files
from tools.gate.observe import (
    Always, AstLint, ChangedHash, Digest, Disasm, Expect, FifoMode, FuzzAgree,
    Lint, NoMutant, Nonzero, Observation, ProverCheck, SameHash, Signals, Size,
    Syscalls, TestsText, TruncOrder, prove,
)
from tools.gate.run import Runner, signal_probe

# Basis, this laptop, 2026-10-04: one seed invocation is well under a second.
# The fuzz budget covers 2000 of those. The whole gate is measured in SCORE.
STEP = 10
LONG = 60
FUZZ_N = 2000
SEED_SHA = "572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72"


class Gate:
    def __init__(self, root):
        self.root = root
        self.sandbox = tempfile.mkdtemp(prefix="hex0-gate-", dir="/var/tmp")
        self.runner = Runner(self.sandbox)
        self.hex_check = load_module(os.path.join(root, "tools/check/hex-check.py"), "hex_check")
        self.seed = os.path.join(root, "ladder/0-hex0/x86_64-linux/hex0")
        self.source = os.path.join(root, "ladder/0-hex0/x86_64-linux/hex0.hex0")
        self.tests = os.path.join(root, "ladder/0-hex0/tests")
        self.before = layout.hash_visible(root)
        try:
            self.outer_before = outer_hash(root)
        except (subprocess.CalledProcessError, OSError):
            self.outer_before = None

    def close(self):
        self.runner.kill_all()
        shutil.rmtree(self.sandbox, ignore_errors=True)

    def prove(self, judge, obs):
        return prove(judge, obs)

    def run(self, argv, timeout=STEP, out_path=None, preexec=None, cwd=None, env=None):
        return self.runner.run(argv, timeout, out_path=out_path, preexec=preexec, cwd=cwd, env=env)

    def require(self, verdict, obs=None):
        if not verdict.ok:
            sys.stderr.write("verify: %s\n" % verdict.reason)
            if obs is not None:
                sys.stderr.write(
                    "verify: status %s exists %s mode %s timed_out %s escaped %s\n"
                    % (obs.status, obs.out_exists, obs.out_mode, obs.timed_out, obs.escaped)
                )
                if obs.out_bytes is not None:
                    sys.stderr.write("verify: out %r\n" % obs.out_bytes[:80])
                if obs.stderr:
                    sys.stderr.write(obs.stderr.decode("utf-8", "replace"))
                if obs.stdout:
                    sys.stderr.write(obs.stdout.decode("utf-8", "replace"))
            raise SystemExit(1)


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def git_env():
    env = os.environ.copy()
    for key in list(env):
        if key.startswith("GIT_"):
            del env[key]
    env["GIT_CONFIG_GLOBAL"] = "/dev/null"
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    env["GIT_OPTIONAL_LOCKS"] = "0"
    return env


def git(root, *args, cwd=None):
    cmd = [
        "git", "-C", cwd or root,
        "-c", "core.hooksPath=/dev/null",
        "-c", "maintenance.auto=false",
        "-c", "core.fsmonitor=false",
        "-c", "user.name=hex0-gate",
        "-c", "user.email=hex0-gate@example.invalid",
        "-c", "commit.gpgsign=false",
        "-c", "diff.autoRefreshIndex=false",
        *args,
    ]
    return subprocess.run(cmd, env=git_env(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def assert_git():
    proc = subprocess.run(
        ["git", "-c", "diff.autoRefreshIndex=false", "--version"],
        stdout=subprocess.PIPE, text=True, env=git_env(),
    )
    text = proc.stdout.strip().split()
    number = text[-1] if text else "0"
    parts = number.split(".")
    major = int(parts[0]) if parts and parts[0].isdigit() else 0
    minor = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 0
    if (major, minor) < (2, 32):
        sys.stderr.write("verify: git 2.32 is required\n")
        raise SystemExit(1)


def outer_hash(root):
    common = subprocess.run(
        ["git", "-c", "diff.autoRefreshIndex=false", "-C", root, "rev-parse", "--path-format=absolute", "--git-common-dir"],
        stdout=subprocess.PIPE, text=True, check=True, env=git_env(),
    ).stdout.strip()
    gitdir = subprocess.run(
        ["git", "-c", "diff.autoRefreshIndex=false", "-C", root, "rev-parse", "--path-format=absolute", "--git-dir"],
        stdout=subprocess.PIPE, text=True, check=True, env=git_env(),
    ).stdout.strip()
    digest = hashlib.sha256()
    for base in sorted({os.path.realpath(common), os.path.realpath(gitdir)}):
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames.sort()
            for filename in sorted(filenames):
                path = os.path.join(dirpath, filename)
                rel = os.path.relpath(path, base)
                digest.update(base.encode())
                digest.update(rel.encode())
                try:
                    with open(path, "rb") as handle:
                        digest.update(handle.read())
                except OSError:
                    continue
    return digest.hexdigest()


def cap_override():
    for line in open("/proc/self/status", encoding="ascii"):
        if line.startswith("CapEff:"):
            return bool(int(line.split()[1], 16) & 2)
    return False


def row_prover(gate):
    obs = gate.run(["/bin/true"])
    refused = prove(Always(), obs)
    empty = prove(NoMutant(), obs)
    judged = Observation(
        always_ok=refused.ok,
        empty_ok=empty.ok,
        empty_reason=empty.reason,
    )
    gate.require(prove(ProverCheck(), judged))
    print("row 0: prover refuses an always-accept judge")
    return obs


def row_hex_check(gate):
    data = open(gate.source, "rb").read()
    status, body = gate.hex_check.decode_bytes(data)
    seed = open(gate.seed, "rb").read()
    obs = Observation(status=status, out_exists=True, out_bytes=body)
    gate.require(prove(Expect("row 1 hex-check", status=0, out_exists=True, out_bytes=seed), obs))
    print("row 1: hex-check identical")


def row_sed(gate):
    proc = gate.run(["/bin/sh", "-c", "sed 's/[#;].*//' \"$1\" | xxd -r -p", "sh", gate.source])
    seed = open(gate.seed, "rb").read()
    obs = Observation(status=proc.status, out_exists=True, out_bytes=proc.stdout)
    gate.require(prove(Expect("row 2 sed|xxd", status=0, out_exists=True, out_bytes=seed), obs))
    print("row 2: sed|xxd identical")


def row_fixpoint(gate):
    out = os.path.join(gate.sandbox, "fixpoint")
    obs = gate.run([gate.seed, gate.source, out], out_path=out)
    seed = open(gate.seed, "rb").read()
    gate.require(prove(Expect("row 3 fixpoint", status=0, out_exists=True, out_bytes=seed, out_mode=0o755), obs))
    print("row 3: fixpoint")


def row_exit42(gate):
    src = os.path.join(gate.tests, "exit42.hex0")
    out = os.path.join(gate.sandbox, "exit42")
    obs = gate.run([gate.seed, src, out], out_path=out)
    status, body = gate.hex_check.decode_bytes(open(src, "rb").read())
    gate.require(prove(Expect("row 4 bytes", status=0, out_exists=True, out_bytes=body, out_mode=0o755), obs), obs)
    ran = gate.run([out])
    gate.require(prove(Expect("row 4 exit42", status=42), ran), ran)
    print("row 4: exit 42")


def row_mode(gate):
    src = os.path.join(gate.tests, "lower.hex0")
    out = os.path.join(gate.sandbox, "mode")
    open(out, "wb").write(b"old")
    os.chmod(out, 0o600)
    obs = gate.run([gate.seed, src, out], out_path=out)
    gate.require(prove(Expect("row 5 mode", status=0, out_exists=True, out_mode=0o755), obs))
    print("row 5: 755")


def row_formats(gate):
    names = (
        "lower.hex0", "upper.hex0", "crlf.hex0", "eof-comment.hex0", "comments.hex0",
        "split.hex0", "comment-nibble.hex0", "comment-cr.hex0", "comment-tab.hex0",
        "comment-high.hex0", "crlf-two.hex0",
    )
    for name in names:
        src = os.path.join(gate.tests, name)
        out = os.path.join(gate.sandbox, name + ".out")
        obs = gate.run([gate.seed, src, out], out_path=out)
        status, body = gate.hex_check.decode_bytes(open(src, "rb").read())
        gate.require(prove(Expect("row 6 " + name, status=0, out_exists=True, out_bytes=body, out_mode=0o755), obs))
    print("row 6: formats")


def row_refusals(gate):
    old = os.path.join(gate.sandbox, "olddata")
    open(old, "wb").write(b"OLDDATA")
    one = b"A"
    specs = (
        ("bad-g.hex0", 4, "empty", "empty"),
        ("vt.hex0", 4, "empty", "empty"),
        ("ff.hex0", 4, "empty", "empty"),
        ("reject-2f.hex0", 4, "one", "one"),
        ("reject-40.hex0", 4, "one", "one"),
        ("reject-80.hex0", 4, "one", "one"),
        ("reject-ff.hex0", 4, "one", "one"),
        ("odd.hex0", 5, "empty", "empty"),
        ("odd-after.hex0", 5, "one", "one"),
    )
    for name, want, absent_kind, pre_kind in specs:
        pair(gate, name, want, os.path.join(gate.tests, name), absent_kind, pre_kind, old, one, b"AB")
    directory = os.path.join(gate.sandbox, "dir-in")
    os.mkdir(directory)
    pair(gate, "directory", 6, directory, "empty", "empty", old, one, b"AB")
    absent_in = os.path.join(gate.sandbox, "missing-in")
    pair(gate, "missing-in", 2, absent_in, "missing", "same", old, one, b"AB")
    missing_dir = os.path.join(gate.sandbox, "no-such-dir", "out")
    obs = gate.run([gate.seed, os.path.join(gate.tests, "lower.hex0"), missing_dir], out_path=missing_dir)
    gate.require(prove(Expect("row 7 missing out", status=3, out_exists=False), obs), obs)
    obs = gate.run([gate.seed])
    gate.require(prove(Expect("row 7 argc", status=1), obs), obs)
    one_path = os.path.join(gate.sandbox, "one-path")
    shutil.copy(old, one_path)
    os.chmod(one_path, 0o640)
    obs = gate.run([gate.seed, one_path], out_path=one_path)
    gate.require(prove(Expect("row 7 one path", status=1, out_exists=True, out_bytes=b"OLDDATA", out_mode=0o640), obs), obs)
    extra = os.path.join(gate.sandbox, "argc4")
    shutil.copy(old, extra)
    os.chmod(extra, 0o640)
    obs = gate.run([gate.seed, os.path.join(gate.tests, "lower.hex0"), extra, "extra"], out_path=extra)
    gate.require(prove(Expect("row 7 argc 4", status=1, out_exists=True, out_bytes=b"OLDDATA", out_mode=0o640), obs), obs)
    dev_mode = os.stat("/dev/null").st_mode & 0o777
    obs = gate.run([gate.seed, os.path.join(gate.tests, "lower.hex0"), "/dev/null"], out_path="/dev/null")
    gate.require(prove(Expect("row 7 non-regular", status=3, out_exists=True, out_mode=dev_mode), obs), obs)
    obs = gate.run([gate.seed, "/dev/null", "/dev/null"])
    gate.require(prove(Expect("row 7 same device", status=7), obs), obs)
    fifo_case(gate, False)
    fifo_case(gate, True)
    same = os.path.join(gate.sandbox, "same")
    shutil.copy(old, same)
    os.chmod(same, 0o640)
    obs = gate.run([gate.seed, same, same], out_path=same)
    gate.require(prove(Expect("row 7 same path", status=7, out_bytes=b"OLDDATA", out_mode=0o640), obs), obs)
    link_case(gate, old)
    plain_readonly(gate)
    print("row 7: refusals")


def row_syscalls(gate):
    out = os.path.join(gate.sandbox, "sys.out")
    trace = os.path.join(gate.sandbox, "sys.trace")
    obs = gate.run(["strace", "-f", "-o", trace, gate.seed, gate.source, out], timeout=LONG, out_path=out)
    names = tuple(syscall_names(read_trace(trace)))
    allowed = tuple(tsv_names(os.path.join(gate.root, "ladder/0-hex0/x86_64-linux/syscalls.tsv")))
    judged = Observation(status=obs.status, names=names, allowed=allowed)
    gate.require(prove(Syscalls(), judged), obs)
    print("row 8: syscalls")


def row_disasm(gate):
    facts = tsv_map(os.path.join(gate.root, "ladder/0-hex0/x86_64-linux/gate.tsv"))
    machine = facts["objdump_machine"]
    width = facts["insn_width"]
    base = int(facts["code_base"])
    stop = int(facts["size"])
    proc = gate.run([
        "objdump", "-D", "-b", "binary", "-m", machine,
        "--start-address", hex(base), "--stop-address", hex(stop),
        "--insn-width", width, gate.seed,
    ], timeout=LONG)
    obs = Observation(
        status=proc.status,
        insns=dumped_triples(proc.stdout.decode("utf-8", "replace")),
        comments=comment_triples(gate.source),
    )
    gate.require(prove(Disasm(), obs), proc)
    print("row 9: 156 instructions")


def row_size(gate):
    data = open(gate.seed, "rb").read()
    phoff = struct.unpack_from("<Q", data, 32)[0]
    filesz = struct.unpack_from("<Q", data, phoff + 32)[0]
    memsz = struct.unpack_from("<Q", data, phoff + 40)[0]
    facts = tsv_map(os.path.join(gate.root, "ladder/0-hex0/x86_64-linux/gate.tsv"))
    obs = Observation(length=len(data), filesz=filesz, memsz=memsz)
    gate.require(prove(Size(int(facts["size"])), obs))
    print("row 10: %d bytes" % len(data))


def row_lint(gate):
    data = open(gate.source, "rb").read()
    obs = Observation(bare=tuple(gate.hex_check.lint_bytes(data)), nonascii=nonascii_offsets(data))
    gate.require(prove(Lint(), obs))
    print("row 11: lint")


def row_fuzz(gate):
    cases = fuzz_cases()
    for case in cases:
        fuzz_one(gate, case)
    print("row 12: fuzz %d" % len(cases))


def row_faults(gate):
    binary = os.path.join(gate.sandbox, "fault")
    proc = gate.run(["gcc", "-O2", "-o", binary, os.path.join(gate.root, "tools/check/fault.c")], timeout=LONG)
    gate.require(prove(Expect("row 13 gcc", status=0), proc), proc)
    ranges = (
        ("4294967296", "3", "1", "1"),
        ("1", "65536", "1", "1"),
        ("1", "3", "65536", "1"),
        ("1", "3", "1", "4294967297"),
    )
    for nr, fd, err, nth in ranges:
        bad = gate.run([binary, nr, fd, err, nth, "/bin/true"])
        gate.require(prove(Expect("row 13 range", status=93), bad), bad)
    facts = tsv_map(os.path.join(gate.root, "ladder/0-hex0/x86_64-linux/gate.tsv"))
    calls = tsv_map(os.path.join(gate.root, "ladder/0-hex0/x86_64-linux/syscalls.tsv"))
    old = os.path.join(gate.sandbox, "fault-old")
    open(old, "wb").write(b"OLDDATA")
    src = os.path.join(gate.sandbox, "fault-in")
    open(src, "wb").write(b"4142\n")
    two = b"AB"
    fault_both(gate, binary, "fstat IN", calls["fstat"], facts["in_fd"], "1", 2, "empty", "same", src, old, two)
    fault_both(gate, binary, "fstat OUT", calls["fstat"], facts["out_fd"], "1", 3, "empty", "same", src, old, two)
    fault_both(gate, binary, "fchmod", calls["fchmod"], facts["out_fd"], "1", 3, "empty", "same", src, old, two)
    fault_both(gate, binary, "read", calls["read"], "-1", "1", 6, "empty", "empty", src, old, two)
    fault_both(gate, binary, "write", calls["write"], "-1", "1", 6, "empty", "empty", src, old, two)
    fault_both(gate, binary, "close", calls["close"], "-1", "1", 6, "two", "two", src, old, two)
    fault_both(gate, binary, "ftruncate", calls["ftruncate"], "-1", "1", 6, "empty", "same755", src, old, two)
    fault_both(gate, binary, "write after a byte", calls["write"], "-1", "2", 6, "one", "one", src, old, b"A")
    fault_both(gate, binary, "read after bytes", calls["read"], "-1", "5", 6, "two", "two", src, old, two)
    trunc_order(gate, binary, facts, calls)
    signal_reinject(gate, binary)
    print("row 13: faults")


def row_sigxfsz(gate):
    import resource
    big = os.path.join(gate.sandbox, "big.hex0")
    open(big, "wb").write(b"00\n" * 2000)
    wrapper = os.path.join(gate.sandbox, "sigxfsz")
    source = os.path.join(gate.sandbox, "sigxfsz.c")
    open(source, "w", encoding="utf-8").write(SIGXFSZ_C)
    built = gate.run(["gcc", "-O2", "-o", wrapper, source], timeout=LONG)
    gate.require(prove(Expect("row 14 gcc", status=0), built), built)
    out = os.path.join(gate.sandbox, "sig-dfl.out")

    def core_off():
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

    obs = gate.run([wrapper, "d", gate.seed, big, out], out_path=out, preexec=core_off, timeout=LONG)
    gate.require(prove(Expect("row 14 SIGXFSZ", status=153), obs), obs)
    print("row 14: SIGXFSZ default")
    out2 = os.path.join(gate.sandbox, "sig-ign.out")
    obs = gate.run([wrapper, "i", gate.seed, big, out2], out_path=out2, timeout=LONG)
    gate.require(prove(Expect("row 15 SIGXFSZ ignored", status=6, out_exists=True, out_bytes=b"\x00" * 1024), obs), obs)
    print("row 15: SIGXFSZ ignored")


def row_capability(gate):
    path = os.path.join(gate.sandbox, "capable")
    open(path, "wb").write(b"")
    os.chmod(path, 0o444)
    obs = gate.run(["unshare", "-r", gate.seed, path, path], out_path=path)
    gate.require(prove(Expect("row 16 capability", status=7, out_mode=0o444), obs))
    print("row 16: capability 7")


def row_empty_argv(gate):
    binary = os.path.join(gate.sandbox, "argc0")
    source = os.path.join(gate.sandbox, "argc0.c")
    open(source, "w", encoding="utf-8").write(ARGC0)
    built = gate.run(["gcc", "-O2", "-o", binary, source])
    gate.require(prove(Expect("row 17 gcc", status=0), built))
    obs = gate.run([binary, gate.seed])
    gate.require(prove(Expect("row 17 empty argv", status=1), obs))
    print("row 17: empty argv")


def row_fd300(gate):
    import resource
    binary = os.path.join(gate.sandbox, "fd300")
    source = os.path.join(gate.sandbox, "fd300.c")
    open(source, "w", encoding="utf-8").write(FD300)
    built = gate.run(["gcc", "-O2", "-o", binary, source])
    gate.require(prove(Expect("row 18 gcc", status=0), built))
    soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
    require_nofile(hard)

    def soft_only():
        resource.setrlimit(resource.RLIMIT_NOFILE, (301, hard))

    obs = gate.run([binary], preexec=soft_only)
    gate.require(prove(Expect("row 18 fd300", status=0), obs))
    print("row 18: fd 300")


def row_sha(gate):
    digest = hashlib.sha256(open(gate.seed, "rb").read()).hexdigest()
    gate.require(prove(Digest(SEED_SHA), Observation(digest=digest)))
    print("row 19: sha256")


def row_layout(gate):
    try:
        text = layout.check(gate.root, "git")
        mutants = layout.prove_mutants(os.path.join(gate.sandbox, "layout-mut"))
    except layout.LayoutError as exc:
        sys.stderr.write("verify: %s\n" % exc)
        raise SystemExit(1)
    obs = Observation(status=0, stdout=text.encode())
    gate.require(prove(Expect("row 20 layout", status=0, stdout_has=b"layout: ok"), obs))
    print("row 20: layout")
    print(mutants)


def row_outer(gate):
    after = outer_hash(gate.root)
    gate.require(prove(SameHash("row 21 outer"), Observation(before=gate.outer_before, after=after)))
    probe_outer(gate)
    print("row 21: outer repository unchanged")


def row_clone(gate):
    dest = os.path.join(gate.sandbox, "candidate")
    fill_candidate(gate.root, dest)
    cloned = os.path.join(gate.sandbox, "cloned")
    git(dest, "clone", "-q", "--template=", "--no-local", dest, cloned)
    proc = gate.run(
        ["python3", "-I", os.path.join(cloned, "tools/verify"), "--layout-only"],
        timeout=LONG, cwd=cloned,
    )
    gate.require(prove(Expect("row 22 clone layout", status=0, stdout_has=b"layout: ok"), proc), proc)
    cr = text_cr(cloned)
    gate.require(prove(Expect("row 22 text", status=0, stdout_has=b"text files: lf"), cr), cr)
    probe_crlf(gate)
    probe_tests_text(gate, dest)
    print("row 22: clone")


def row_hostile(gate):
    copy = os.path.join(gate.sandbox, "hostile")
    shutil.copytree(gate.root, copy, ignore=shutil.ignore_patterns(".git", "out"))
    seed = os.path.join(copy, "ladder/0-hex0/x86_64-linux/hex0")
    data = bytearray(open(seed, "rb").read())
    data[10] ^= 0x01
    open(seed, "wb").write(data)
    os.chmod(seed, 0o755)
    bash_env = os.path.join(gate.sandbox, "hostile.bash")
    open(bash_env, "w", encoding="utf-8").write("cmp() { return 0; }\n")
    site = os.path.join(gate.sandbox, "site")
    os.makedirs(site)
    open(os.path.join(site, "sitecustomize.py"), "w", encoding="utf-8").write("import sys\nsys.exit(0)\n")
    env = os.environ.copy()
    env["BASH_ENV"] = bash_env
    env["PYTHONPATH"] = site
    env["PYTHONHOME"] = site
    proc = gate.run(
        ["python3", "-I", os.path.join(copy, "tools/verify")],
        timeout=LONG, cwd=copy, env=env,
    )
    gate.require(prove(Nonzero("row 23 hostile"), proc), proc)
    print("row 23: hostile startup is red")


def row_signals(gate):
    for name in ("INT", "TERM", "HUP"):
        signal_one(gate, name)
    print("row 24: signals")


def row_lock(gate):
    proc = gate.run(
        ["python3", "-I", os.path.join(gate.root, "tools/verify")],
        timeout=STEP, cwd=gate.root,
    )
    gate.require(prove(Expect("row 25 lock", status=1, stderr_has=b"out/ is locked"), proc), proc)
    print("row 25: out/ lock")


def row_ast(gate):
    bad, good, static = mutant_files(gate.sandbox)
    obs = Observation(
        hits=tuple(lint_gate(gate.root)),
        bad_hits=tuple(lint_file(bad)),
        good_hits=tuple(lint_file(good)),
        static_hits=tuple(lint_file(static)),
    )
    gate.require(prove(AstLint(), obs))
    print("row 26: ast lint")


def row_effect(gate):
    after = layout.hash_visible(gate.root)
    gate.require(prove(SameHash("row 27 tree"), Observation(before=gate.before, after=after)))
    copy = os.path.join(gate.sandbox, "effect")
    os.makedirs(os.path.join(copy, "tools"))
    seed = os.path.join(copy, "hex0")
    open(seed, "wb").write(b"\x7fELF")
    before = layout.hash_visible(copy)
    open(seed, "wb").write(b"\x7fELG")
    gate.require(prove(ChangedHash("row 27 seed rewrite"), Observation(before=before, after=layout.hash_visible(copy))))
    tool = os.path.join(copy, "tools", "wrote")
    before_tool = layout.hash_visible(copy)
    open(tool, "w", encoding="utf-8").write("x\n")
    gate.require(prove(ChangedHash("row 27 tools write"), Observation(before=before_tool, after=layout.hash_visible(copy))))
    print("row 27: tree unchanged")


def finish(gate):
    print("verify: judged, outer repository unchanged")


def tsv_map(path):
    found = {}
    for line in open(path, encoding="utf-8"):
        if "\t" not in line:
            continue
        key, value = line.rstrip("\n").split("\t", 1)
        if key in found:
            raise SystemExit("verify: duplicated tsv key %s" % key)
        found[key] = value
    return found


def comment_triples(source):
    import re
    comments = []
    seen = False
    for line in open(source, encoding="utf-8"):
        if line.startswith("# ## Code"):
            seen = True
            continue
        if not seen or "#" not in line:
            continue
        body, comment = line.split("#", 1)
        hexes = body.split()
        if not hexes:
            continue
        text = " ".join(comment.split())
        match = re.match(r"^\+([0-9A-Fa-f]+) (.*)$", text)
        if match:
            comments.append((int(match.group(1), 16), bytes.fromhex("".join(hexes)), match.group(2)))
    return tuple(comments)


def dumped_triples(dump):
    import re
    got = []
    for line in dump.splitlines():
        match = re.match(r"^\s*([0-9a-f]+):(.*)$", line)
        if not match:
            continue
        addr = int(match.group(1), 16)
        words = match.group(2).split()
        raw = []
        mnemonic = []
        started = False
        for word in words:
            if not started and re.fullmatch(r"[0-9a-f]{2}", word):
                raw.append(word)
                continue
            started = True
            mnemonic.append(word)
        if mnemonic:
            got.append((addr, bytes.fromhex("".join(raw)), " ".join(mnemonic)))
    return tuple(got)


def probe_outer(gate):
    repo = os.path.join(gate.sandbox, "outer-repo")
    os.makedirs(repo)
    git(repo, "init", "-q", "--template=")
    open(os.path.join(repo, "a"), "w", encoding="utf-8").write("a\n")
    git(repo, "add", "a")
    git(repo, "commit", "-q", "--no-verify", "-m", "a")
    before = outer_hash(repo)
    git(repo, "update-ref", "refs/heads/evil", "HEAD")
    gate.require(prove(ChangedHash("row 21 outer ref"), Observation(before=before, after=outer_hash(repo))))
    git(repo, "update-ref", "-d", "refs/heads/evil")
    info = os.path.join(repo, ".git", "info")
    os.makedirs(info, exist_ok=True)
    exclude = os.path.join(info, "exclude")
    open(exclude, "a", encoding="utf-8").write("# x\n")
    gate.require(prove(ChangedHash("row 21 outer exclude"), Observation(before=before, after=outer_hash(repo))))
    link = os.path.join(gate.sandbox, "outer-link")
    os.makedirs(link)
    real = os.path.realpath(os.path.join(repo, ".git"))
    open(os.path.join(link, ".git"), "w", encoding="utf-8").write("gitdir: %s\n" % real)
    before_link = outer_hash(link)
    open(exclude, "a", encoding="utf-8").write("# y\n")
    gate.require(prove(ChangedHash("row 21 outer gitfile"), Observation(before=before_link, after=outer_hash(link))))


ARGC0 = r'''
#include <sys/ptrace.h>
#include <sys/user.h>
#include <sys/wait.h>
#include <signal.h>
#include <unistd.h>
#include <stdio.h>
int main(int argc, char **argv) {
  pid_t pid;
  int status;
  if (argc != 2) return 98;
  pid = fork();
  if (pid == 0) {
    ptrace(PTRACE_TRACEME, 0, 0, 0);
    raise(SIGSTOP);
    execl(argv[1], argv[1], (char *)0);
    _exit(95);
  }
  waitpid(pid, &status, 0);
  ptrace(PTRACE_SETOPTIONS, pid, 0, PTRACE_O_TRACEEXEC);
  ptrace(PTRACE_CONT, pid, 0, 0);
  waitpid(pid, &status, 0);
  /* At the exec stop, argc lives at the child's rsp. Write 0. */
  {
    unsigned long rsp;
    struct user_regs_struct regs;
    ptrace(PTRACE_GETREGS, pid, 0, &regs);
    rsp = regs.rsp;
    ptrace(PTRACE_POKEDATA, pid, rsp, 0);
  }
  ptrace(PTRACE_CONT, pid, 0, 0);
  waitpid(pid, &status, 0);
  if (WIFEXITED(status)) return WEXITSTATUS(status);
  return 96;
}
'''

FD300 = r'''
#define _GNU_SOURCE
#include <fcntl.h>
#include <unistd.h>
#include <sys/syscall.h>
int main(void) {
  int fd = open("/dev/null", O_RDONLY);
  if (fd < 0) return 2;
  if (dup2(fd, 300) < 0) return 3;
  if (syscall(SYS_close_range, 3, ~0U, 0) != 0) return 4;
  if (fcntl(300, F_GETFD) != -1) return 5;
  return 0;
}
'''

SIGXFSZ_C = r'''
#include <signal.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/resource.h>
int main(int argc, char **argv) {
  struct rlimit lim;
  struct rlimit core;
  if (argc < 5) return 98;
  if (argv[1][0] == 'd') {
    signal(SIGXFSZ, SIG_DFL);
    if (getrlimit(RLIMIT_CORE, &core) != 0) return 97;
    if (core.rlim_cur != 0) return 94;
  } else {
    signal(SIGXFSZ, SIG_IGN);
  }
  lim.rlim_cur = 1024;
  lim.rlim_max = 1024;
  if (setrlimit(RLIMIT_FSIZE, &lim) != 0) return 96;
  execv(argv[2], argv + 2);
  return 99;
}
'''


def Nonzero_obs(obs):
    """The lock judge reads the needle. A zero status is refused by Nonzero, separately."""
    from tools.gate.observe import Observation
    status = obs.status if obs.status not in (None, 0) else 1
    return Observation(status=status, stderr=obs.stderr, stdout=obs.stdout, timed_out=obs.timed_out)


def shaped(kind, old, one, two):
    if kind == "missing":
        return {"out_exists": False}
    if kind == "empty":
        return {"out_exists": True, "out_bytes": b"", "out_mode": 0o755}
    if kind == "same":
        return {"out_exists": True, "out_bytes": open(old, "rb").read() if isinstance(old, str) else old, "out_mode": 0o640}
    if kind == "same755":
        body = open(old, "rb").read() if isinstance(old, str) else old
        return {"out_exists": True, "out_bytes": body, "out_mode": 0o755}
    if kind == "one":
        return {"out_exists": True, "out_bytes": one, "out_mode": 0o755}
    if kind == "two":
        return {"out_exists": True, "out_bytes": two, "out_mode": 0o755}
    raise SystemExit("verify: unknown shape %s" % kind)


def pair(gate, label, want, src, absent_kind, pre_kind, old, one, two):
    absent = os.path.join(gate.sandbox, "abs-" + label)
    if os.path.lexists(absent):
        os.remove(absent)
    obs = gate.run([gate.seed, src, absent], out_path=absent)
    fields = shaped(absent_kind, old, one, two)
    gate.require(prove(Expect("row 7 " + label, status=want, **fields), obs), obs)
    pre = os.path.join(gate.sandbox, "pre-" + label)
    shutil.copy(old, pre)
    os.chmod(pre, 0o640)
    obs = gate.run([gate.seed, src, pre], out_path=pre)
    fields = shaped(pre_kind, old, one, two)
    gate.require(prove(Expect("row 7 " + label + " pre", status=want, **fields), obs), obs)


def fifo_case(gate, reader):
    path = os.path.join(gate.sandbox, "fifo-reader" if reader else "fifo-none")
    os.mkfifo(path)
    before = os.stat(path).st_mode & 0o777
    held = open_reader(path, reader)
    obs = gate.run([gate.seed, os.path.join(gate.tests, "lower.hex0"), path], out_path=path)
    close_reader(held)
    after = os.stat(path).st_mode & 0o777
    judged = Observation(status=obs.status, prior_mode=before, out_mode=after)
    gate.require(prove(FifoMode(), judged), obs)


def link_case(gate, old):
    target = os.path.join(gate.sandbox, "hard")
    shutil.copy(old, target)
    os.chmod(target, 0o640)
    link = os.path.join(gate.sandbox, "hard.link")
    os.link(target, link)
    obs = gate.run([gate.seed, target, link], out_path=target)
    gate.require(prove(Expect("row 7 hard link", status=7, out_bytes=b"OLDDATA", out_mode=0o640), obs), obs)
    sym_target = os.path.join(gate.sandbox, "sym.target")
    shutil.copy(old, sym_target)
    os.chmod(sym_target, 0o640)
    os.symlink("sym.target", os.path.join(gate.sandbox, "sym.link"))
    obs = gate.run([gate.seed, sym_target, os.path.join(gate.sandbox, "sym.link")], out_path=sym_target)
    gate.require(prove(Expect("row 7 symlink", status=7, out_bytes=b"OLDDATA", out_mode=0o640), obs), obs)


def plain_readonly(gate):
    message = b"CAP_DAC_OVERRIDE"
    script = os.path.join(gate.sandbox, "cap-refuse.py")
    open(script, "w", encoding="utf-8").write(
        "import sys\n"
        "for line in open('/proc/self/status'):\n"
        "    if line.startswith('CapEff:') and int(line.split()[1], 16) & 2:\n"
        "        sys.stderr.write('CAP_DAC_OVERRIDE is effective\\n')\n"
        "        raise SystemExit(1)\n"
        "raise SystemExit(0)\n"
    )
    refused = gate.run(["unshare", "-r", "python3", "-I", script])
    gate.require(prove(Expect("row 7 capability refusal", status=1, stderr_has=message), refused), refused)
    if cap_override():
        sys.stderr.write("verify: row 7 read-only refused, CAP_DAC_OVERRIDE is effective\n")
        raise SystemExit(1)
    path = os.path.join(gate.sandbox, "readonly")
    open(path, "wb").write(b"OLDDATA")
    os.chmod(path, 0o444)
    obs = gate.run([gate.seed, path, path], out_path=path)
    gate.require(prove(Expect("row 7 read-only", status=3, out_bytes=b"OLDDATA", out_mode=0o444), obs), obs)


def fault_both(gate, binary, label, nr, fd, nth, want, absent_kind, pre_kind, src, old, body):
    absent = os.path.join(gate.sandbox, "fabs-" + label.replace(" ", "-"))
    if os.path.exists(absent):
        os.remove(absent)
    obs = gate.run([binary, nr, fd, "5", nth, gate.seed, src, absent], out_path=absent, timeout=LONG)
    fields = shaped(absent_kind, old, b"A", body)
    gate.require(prove(Expect("row 13 " + label, status=want, **fields), obs), obs)
    pre = os.path.join(gate.sandbox, "fpre-" + label.replace(" ", "-"))
    shutil.copy(old, pre)
    os.chmod(pre, 0o640)
    obs = gate.run([binary, nr, fd, "5", nth, gate.seed, src, pre], out_path=pre, timeout=LONG)
    fields = shaped(pre_kind, old, b"A", body)
    gate.require(prove(Expect("row 13 " + label + " pre", status=want, **fields), obs), obs)
    ctl = os.path.join(gate.sandbox, "fctl-" + label.replace(" ", "-"))
    if os.path.exists(ctl):
        os.remove(ctl)
    obs = gate.run([gate.seed, src, ctl], out_path=ctl)
    gate.require(prove(Expect("row 13 control", status=0, out_exists=True, out_bytes=b"AB", out_mode=0o755), obs), obs)


def trunc_order(gate, binary, facts, calls):
    old_pat = bytes.fromhex(facts["trunc_fchmod_then_ftruncate"])
    new_pat = bytes.fromhex(facts["trunc_ftruncate_then_fchmod"])
    data = open(gate.seed, "rb").read()
    if data.count(old_pat) != 1:
        sys.stderr.write("verify: trunc pattern found %d\n" % data.count(old_pat))
        raise SystemExit(1)
    mutant = os.path.join(gate.sandbox, "trunc-first")
    open(mutant, "wb").write(data.replace(old_pat, new_pat, 1))
    os.chmod(mutant, 0o755)
    pre = os.path.join(gate.sandbox, "trunc-pre")
    open(pre, "wb").write(b"OLDDATA")
    os.chmod(pre, 0o640)
    src = os.path.join(gate.sandbox, "trunc-in")
    open(src, "wb").write(b"41\n")
    obs = gate.run(
        [binary, calls["fchmod"], facts["out_fd"], "5", "1", mutant, src, pre],
        out_path=pre, timeout=LONG,
    )
    gate.require(prove(TruncOrder(), obs), obs)


def signal_reinject(gate, binary):
    source = os.path.join(gate.sandbox, "sigterm.c")
    built_path = os.path.join(gate.sandbox, "sigterm")
    open(source, "w", encoding="utf-8").write(
        "#include <signal.h>\n#include <unistd.h>\nint main(void) {\n"
        "  signal(SIGTERM, SIG_DFL);\n  raise(SIGTERM);\n  return 0;\n}\n"
    )
    built = gate.run(["gcc", "-O2", "-static", "-o", built_path, source], timeout=LONG)
    gate.require(prove(Expect("row 13 sigterm gcc", status=0), built), built)
    obs = gate.run([binary, "0", "-1", "1", "2", built_path], timeout=LONG)
    gate.require(prove(Expect("row 13 signal", status=143), obs), obs)


def syscall_names(text):
    import re
    found = []
    for line in text.splitlines():
        match = re.match(r"^(?:\[[^\]]+\]\s+)?\d+\s+([A-Za-z0-9_]+)\(", line)
        if match:
            found.append(match.group(1))
        elif re.match(r"^(execve)\(", line):
            found.append("execve")
    return found


def tsv_names(path):
    names = []
    for line in open(path, encoding="utf-8"):
        parts = line.split()
        if parts:
            names.append(parts[0])
    return names


def fill_candidate(root, dest):
    shutil.copytree(
        root, dest,
        ignore=shutil.ignore_patterns(".git", "out", "__pycache__"),
    )
    git(root, "init", "-q", "--template=", dest)
    bare = dest + ".archive.git"
    git(root, "init", "-q", "--bare", "--template=", bare)
    common = subprocess.run(
        ["git", "-c", "diff.autoRefreshIndex=false", "-C", root, "rev-parse", "--path-format=absolute", "--git-common-dir"],
        stdout=subprocess.PIPE, text=True, check=True, env=git_env(),
    ).stdout.strip()
    os.makedirs(os.path.join(bare, "objects", "info"), exist_ok=True)
    open(os.path.join(bare, "objects", "info", "alternates"), "w", encoding="utf-8").write(
        os.path.join(common, "objects") + "\n"
    )
    git(bare, "update-ref", "refs/gate/archive", "c45603e")
    bundle = os.path.join(dest, "archive.bundle")
    git(bare, "bundle", "create", bundle, "refs/gate/archive")
    git(dest, "fetch", "--no-tags", bundle, "refs/gate/archive:refs/gate/archive")
    shutil.rmtree(bare, ignore_errors=True)
    os.remove(bundle)
    git(dest, "add", "-A")
    tree = git(dest, "write-tree")
    if tree.returncode != 0:
        sys.stderr.write(tree.stderr.decode())
        raise SystemExit(1)
    commit = git(dest, "commit-tree", tree.stdout.decode().strip(), "-p", "refs/gate/archive", "-m", "hex0 gate sandbox tree")
    if commit.returncode != 0:
        sys.stderr.write(commit.stderr.decode())
        raise SystemExit(1)
    git(dest, "update-ref", "HEAD", commit.stdout.decode().strip())


def text_cr(root):
    listed = subprocess.run(
        ["git", "-c", "diff.autoRefreshIndex=false", "-C", root, "ls-files", "-z"],
        stdout=subprocess.PIPE, env=git_env(),
    )
    rels = [item.decode() for item in listed.stdout.split(b"\0") if item]
    proc = subprocess.run(
        ["git", "-c", "diff.autoRefreshIndex=false", "-C", root, "check-attr", "-z", "--stdin", "text"],
        input=b"\0".join(item.encode() for item in rels) + b"\0",
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=git_env(),
    )
    parts = proc.stdout.split(b"\0")
    values = {}
    index = 0
    while index + 2 < len(parts):
        values[parts[index].decode()] = parts[index + 2].decode()
        index += 3
    for rel in rels:
        value = values.get(rel, "unspecified")
        if value in ("unset", "unspecified"):
            continue
        data = open(os.path.join(root, rel), "rb").read()
        if b"\0" in data:
            continue
        if b"\r" in data:
            from tools.gate.observe import Observation
            message = ("text file contains CR: %s\n" % rel).encode()
            return Observation(status=1, stdout=message, stderr=message)
    from tools.gate.observe import Observation
    return Observation(status=0, stdout=b"text files: lf")


def probe_crlf(gate):
    repo = os.path.join(gate.sandbox, "crlf-repo")
    os.makedirs(repo)
    git(repo, "init", "-q", "--template=")
    open(os.path.join(repo, ".gitattributes"), "w", encoding="utf-8").write("*.py text eol=crlf\n")
    open(os.path.join(repo, "a.py"), "w", encoding="utf-8").write("a\n")
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "--no-verify", "-m", "crlf")
    cloned = os.path.join(gate.sandbox, "crlf-clone")
    git(repo, "clone", "-q", "--template=", "--no-local", repo, cloned)
    cr = text_cr(cloned)
    gate.require(prove(Nonzero("row 22 crlf"), cr), cr)


def probe_tests_text(gate, candidate):
    edited = os.path.join(gate.sandbox, "tests-text")
    shutil.copytree(candidate, edited, ignore=shutil.ignore_patterns())
    # copytree of a git repo copies .git. That is a sandbox copy, not a landing worktree.
    attr = os.path.join(edited, ".gitattributes")
    lines = open(attr, encoding="utf-8").read().splitlines()
    kept = [line for line in lines if "tests/" not in line]
    open(attr, "w", encoding="utf-8").write("\n".join(kept) + "\n")
    git(edited, "add", "-A")
    git(edited, "commit", "-q", "--no-verify", "-m", "drop the fixture text mark")
    cloned = os.path.join(gate.sandbox, "tests-text-clone")
    git(edited, "clone", "-q", "--template=", "--no-local", edited, cloned)
    cr = text_cr(cloned)
    # eol=lf rewrites the fixture, so the work tree no longer matches the blob.
    shown = subprocess.run(
        ["git", "-c", "diff.autoRefreshIndex=false", "-C", cloned, "hash-object", "ladder/0-hex0/tests/crlf.hex0"],
        stdout=subprocess.PIPE, env=git_env(),
    )
    blob = subprocess.run(
        ["git", "-c", "diff.autoRefreshIndex=false", "-C", cloned, "rev-parse", "HEAD:ladder/0-hex0/tests/crlf.hex0"],
        stdout=subprocess.PIPE, env=git_env(),
    )
    obs = Observation(shown=shown.stdout.strip(), blob=blob.stdout.strip(), cr_status=cr.status)
    gate.require(prove(TestsText(), obs), cr)


def read_trace(path):
    if not os.path.exists(path):
        return ""
    return open(path, encoding="utf-8", errors="replace").read()


def nonascii_offsets(data):
    found = []
    for index, byte in enumerate(data):
        if byte >= 128 or byte == 13:
            found.append(index)
    return tuple(found)


def fuzz_cases():
    near = [ord(ch) for ch in ":@G`gx/"] + [0, 0x7F, 0x80, 0xFF]
    cases = []
    for byte in near:
        cases.append(bytes([byte]))
        cases.append(bytes([0x30, byte]))
    rng = random.Random(20261004)
    while len(cases) < FUZZ_N:
        length = rng.randrange(0, 8)
        cases.append(bytes(rng.randrange(256) for _ in range(length)))
    return cases


def fuzz_one(gate, case):
    ref_status, ref_body = reference(case)
    hex_status, hex_body = gate.hex_check.decode_bytes(case)
    agreed = Observation(
        ref_status=ref_status,
        ref_out=ref_body,
        check_status=hex_status,
        check_out=hex_body,
    )
    gate.require(prove(FuzzAgree(), agreed))
    src = os.path.join(gate.sandbox, "fuzz.in")
    out = os.path.join(gate.sandbox, "fuzz.out")
    open(src, "wb").write(case)
    if os.path.exists(out):
        os.remove(out)
    obs = gate.run([gate.seed, src, out], timeout=STEP, out_path=out)
    gate.require(prove(Expect(
        "row 12 fuzz",
        status=ref_status,
        out_exists=True,
        out_bytes=ref_body,
        out_mode=0o755,
    ), obs))


def require_nofile(hard):
    import resource
    if hard != resource.RLIM_INFINITY and hard < 301:
        sys.stderr.write("verify: soft NOFILE hard limit is below 301\n")
        raise SystemExit(1)


def signal_one(gate, name):
    code, _out, err, left, children = signal_probe(name, gate.sandbox)
    obs = Observation(code=code, left=len(left), children=len(children), stderr=err)
    gate.require(prove(Signals(name), obs))


def open_reader(path, reader):
    if not reader:
        return None
    return os.open(path, os.O_RDWR)


def close_reader(held):
    if held is None:
        return
    os.close(held)
