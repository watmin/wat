#!/usr/bin/env python3
"""Row 8. A strace of hex0 may contain only the syscalls it claims.

Exit codes: 2 usage, 1 a set mismatch, 99 an unexpected failure.
Exactly one execve (the kernel's) and the names in the tsv, nothing else.
"""

import re
import sys
from collections import Counter


def names_of(text):
    found = []
    for line in text.splitlines():
        match = re.match(r"^(?:\[[^\]]+\]\s+)?\d+\s+([A-Za-z0-9_]+)\(", line)
        if match:
            found.append(match.group(1))
        elif re.match(r"^(execve)\(", line):
            found.append("execve")
    return found


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("usage: syscalls-check.py TRACE SYSCALLS.TSV\n")
        return 2
    try:
        text = open(argv[0], encoding="utf-8", errors="replace").read()
        allowed = []
        for line in open(argv[1], encoding="utf-8"):
            parts = line.split()
            if parts:
                allowed.append(parts[0])
    except FileNotFoundError as exc:
        sys.stderr.write("syscalls-check: missing file: %s\n" % exc)
        return 99
    found = names_of(text)
    if not found:
        sys.stderr.write("row 8: no syscalls parsed\n")
        return 1
    counts = Counter(found)
    if counts.get("execve", 0) != 1:
        sys.stderr.write("row 8: execve count %d\n" % counts.get("execve", 0))
        return 1
    want = set(name for name in allowed if name != "execve")
    got = set(name for name in found if name != "execve")
    bad = sorted(got - want)
    if bad:
        sys.stderr.write("row 8: unexpected " + " ".join(bad) + "\n")
        return 1
    missing = sorted(want - got)
    if missing:
        sys.stderr.write("row 8: missing " + " ".join(missing) + "\n")
        return 1
    shown = ["execve"] + [name for name in allowed if name != "execve"]
    sys.stdout.write("row 8: " + " ".join(shown) + "\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:
        sys.stderr.write("syscalls-check: %s\n" % exc)
        sys.exit(99)
