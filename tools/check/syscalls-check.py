#!/usr/bin/env python3
"""Row 8. A strace of hex0 may contain only the syscalls it claims."""

import re
import sys

ALLOWED = [
    "execve",
    "open",
    "fstat",
    "fchmod",
    "ftruncate",
    "read",
    "write",
    "close",
    "exit",
]


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
    if len(argv) != 1:
        sys.stderr.write("usage: syscalls-check.py TRACE\n")
        return 2
    text = open(argv[0], encoding="utf-8", errors="replace").read()
    found = names_of(text)
    if not found:
        sys.stderr.write("row 8: no syscalls parsed\n")
        return 1
    bad = sorted(set(name for name in found if name not in ALLOWED))
    if bad:
        sys.stderr.write("row 8: unexpected " + " ".join(bad) + "\n")
        return 1
    missing = [name for name in ALLOWED if name not in found]
    if missing:
        sys.stderr.write("row 8: missing " + " ".join(missing) + "\n")
        return 1
    sys.stdout.write("row 8: " + " ".join(ALLOWED) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
