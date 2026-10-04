#!/usr/bin/env python3
"""Clone row. A text file in a checkout must not contain CR.

Exit codes: 2 usage, 1 a CR in a text file, 99 an unexpected failure.
Text is whatever git's text attribute does not mark unset. Fixtures
marked -text may hold CR. The seed is binary.
"""

import subprocess
import sys
from pathlib import Path


def text_values(root, rels):
    git = Path(root) / "tools" / "check" / "git-sandbox"
    proc = subprocess.run(
        [str(git), "-C", root, "check-attr", "--stdin", "text"],
        input=("\n".join(rels) + "\n").encode("utf-8"),
        check=False,
        capture_output=True,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr.decode("utf-8", "replace"))
        return None
    values = {}
    for line in proc.stdout.decode("utf-8", "replace").splitlines():
        # path: text: value
        if ": text: " not in line:
            continue
        rel, value = line.split(": text: ", 1)
        values[rel] = value.strip()
    return values


def main(argv):
    if len(argv) != 1:
        sys.stderr.write("usage: text-cr.py ROOT\n")
        return 2
    root = Path(argv[0])
    git = root / "tools" / "check" / "git-sandbox"
    listed = subprocess.run(
        [str(git), "-C", str(root), "ls-files", "-z"],
        check=False,
        capture_output=True,
    )
    if listed.returncode != 0:
        sys.stderr.write(listed.stderr.decode("utf-8", "replace"))
        return 99
    rels = []
    for relb in listed.stdout.split(b"\0"):
        if relb:
            rels.append(relb.decode("utf-8"))
    values = text_values(str(root), rels)
    if values is None:
        return 99
    for rel in rels:
        value = values.get(rel, "unspecified")
        if value in ("unset", "unspecified"):
            continue
        data = (root / rel).read_bytes()
        if b"\0" in data:
            continue
        if b"\r" in data:
            sys.stdout.write("text file contains CR: %s\n" % rel)
            return 1
    sys.stdout.write("text files: lf\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:
        sys.stderr.write("text-cr: %s\n" % exc)
        sys.exit(99)
