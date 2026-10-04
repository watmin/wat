"""The runner owns the process, the timer and the sandbox. It does not judge."""

import os
import signal
import subprocess
import time
from dataclasses import dataclass

from tools.gate.observe import Observation


@dataclass
class Live:
    session: int
    proc: subprocess.Popen


class Runner:
    def __init__(self, sandbox):
        self.sandbox = sandbox
        self.live = []
        self.become_subreaper()

    def become_subreaper(self):
        import ctypes
        libc = ctypes.CDLL(None, use_errno=True)
        if libc.prctl(36, 1, 0, 0, 0) != 0:
            err = ctypes.get_errno()
            raise OSError(err, "prctl subreaper")

    def run(self, argv, timeout, out_path=None, cwd=None, env=None, preexec=None):
        proc = subprocess.Popen(
            argv,
            cwd=cwd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
            preexec_fn=preexec,
        )
        self.live.append(Live(proc.pid, proc))
        timed_out = False
        try:
            stdout, stderr = proc.communicate(timeout=timeout)
            status = shell_status(proc.returncode)
        except subprocess.TimeoutExpired:
            timed_out = True
            self.kill_session(proc.pid)
            stdout, stderr = proc.communicate()
            status = shell_status(proc.returncode)
        self.live = [item for item in self.live if item.proc.pid != proc.pid]
        escaped = self.reap_orphans(proc.pid)
        for pid in escaped:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        out_exists, out_bytes, out_mode = stat_out(out_path)
        return Observation(
            status=status,
            out_exists=out_exists,
            out_bytes=out_bytes,
            out_mode=out_mode,
            stdout=stdout or b"",
            stderr=stderr or b"",
            timed_out=timed_out,
            escaped=tuple(escaped),
        )

    def kill_session(self, session):
        try:
            os.killpg(session, signal.SIGKILL)
        except ProcessLookupError:
            pass

    def kill_all(self):
        for item in list(self.live):
            self.kill_session(item.session)
        self.reap_orphans(0)

    def reap_orphans(self, session):
        """Descendants reparented to this subreaper, and anyone left in the session."""
        found = []
        children = read_children()
        for pid in children:
            if pid == os.getpid() or pid == session:
                continue
            found.append(pid)
        if session:
            try:
                os.killpg(session, 0)
            except ProcessLookupError:
                pass
            else:
                found.append(session)
        while True:
            try:
                pid, _ = os.waitpid(-1, os.WNOHANG)
            except ChildProcessError:
                break
            if pid == 0:
                break
        return tuple(pid for pid in found if pid_alive(pid))


def read_children():
    path = "/proc/self/task/%d/children" % os.getpid()
    try:
        text = open(path, "r", encoding="ascii").read().split()
    except OSError:
        return []
    return [int(item) for item in text if item.isdigit()]


def pid_alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def shell_status(code):
    """The wait status, as a shell reports a signal: 128 plus the signal number."""
    if code is None:
        return None
    if code < 0:
        return 128 + (-code)
    return code


def stat_out(path):
    if path is None:
        return None, None, None
    if not os.path.lexists(path):
        return False, None, None
    st = os.lstat(path)
    mode = st.st_mode & 0o777
    if os.path.isfile(path) and not os.path.islink(path):
        with open(path, "rb") as handle:
            body = handle.read()
    else:
        body = None
    return True, body, mode


def signal_probe(sig_name, sandbox):
    """A child gate blocks in a step until an event, then the signal is delivered."""
    import tempfile
    fifo = os.path.join(sandbox, "probe-%s.fifo" % sig_name)
    if os.path.exists(fifo):
        os.remove(fifo)
    os.mkfifo(fifo)
    child_dir = tempfile.mkdtemp(prefix="hex0-probe-", dir="/var/tmp")
    script = os.path.join(sandbox, "probe.py")
    open(script, "w", encoding="utf-8").write(PROBE)
    proc = subprocess.Popen(
        ["python3", "-I", script, sig_name, fifo, child_dir],
        start_new_session=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    deadline = time.time() + 5
    while time.time() < deadline:
        try:
            fd = os.open(fifo, os.O_WRONLY | os.O_NONBLOCK)
            os.close(fd)
            break
        except OSError:
            if proc.poll() is not None:
                err = proc.stderr.read()
                raise RuntimeError("probe exited early: %s" % err)
            time.sleep(0.01)
    else:
        os.killpg(proc.pid, signal.SIGKILL)
        raise RuntimeError("probe fifo never opened")
    sig = {"INT": signal.SIGINT, "TERM": signal.SIGTERM, "HUP": signal.SIGHUP}[sig_name]
    os.killpg(proc.pid, sig)
    try:
        stdout, stderr = proc.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        stdout, stderr = proc.communicate()
    left = []
    if os.path.isdir(child_dir):
        left.append(child_dir)
    children = read_children()
    return proc.returncode, stdout, stderr, left, children


PROBE = r'''
import os, signal, sys
sig_name, fifo, sandbox = sys.argv[1:]
os.makedirs(sandbox, exist_ok=True)
sig = {"INT": signal.SIGINT, "TERM": signal.SIGTERM, "HUP": signal.SIGHUP}[sig_name]

def stop(signum, frame):
    import shutil
    shutil.rmtree(sandbox, ignore_errors=True)
    raise SystemExit(3)

signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGHUP, stop)
# The open completes in the parent. That is the event, not a sleep.
fd = os.open(fifo, os.O_RDONLY)
os.read(fd, 1)
raise SystemExit(0)
'''
