#!/usr/bin/env python3
"""Row 9. Instruction comments against objdump of the code blob.

Each comment begins with +FILEOFFSET. objdump is run with --adjust-vma
so that address is already a file offset. The rest of the comment is the
disassembly, whitespace collapsed. Headings are lines with no hex.

Exit codes: 2 usage, 1 a row-9 mismatch, 99 an unexpected failure.
"""

import re
import sys


def instructions(source_text):
    seen = False
    rows = []
    for line in source_text.splitlines():
        if line.startswith("# ## Code"):
            seen = True
            continue
        if not seen or "#" not in line:
            continue
        body, comment = line.split("#", 1)
        hexes = body.split()
        if not hexes:
            continue
        if not all(re.fullmatch(r"[0-9A-Fa-f]{2}", item) for item in hexes):
            return "row 9: not hex: " + line, None
        blob = bytes(int(item, 16) for item in hexes)
        text = " ".join(comment.split())
        match = re.match(r"^\+([0-9A-Fa-f]+) (.*)$", text)
        if not match:
            return "row 9: comment has no file offset: " + text, None
        rows.append((blob, int(match.group(1), 16), match.group(2)))
    if not seen:
        return "row 9: no code marker", None
    return None, rows


def objdump_ops(text):
    ops = []
    for line in text.splitlines():
        match = re.match(r"^\s*([0-9a-f]+):\s*((?:[0-9a-f]{2}\s+)+)(.*)$", line)
        if not match:
            continue
        addr = int(match.group(1), 16)
        blob = bytes(int(item, 16) for item in match.group(2).split())
        ins = " ".join(match.group(3).split())
        ops.append((addr, blob, ins))
    return ops


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("usage: disasm-check.py SOURCE CODEBIN OBJDUMP\n")
        return 2
    source = open(argv[0], encoding="utf-8").read()
    code = open(argv[1], "rb").read()
    dumped = open(argv[2], encoding="utf-8", errors="replace").read()
    err, rows = instructions(source)
    if err:
        sys.stderr.write(err + "\n")
        return 1
    ops = objdump_ops(dumped)
    if len(rows) != len(ops):
        sys.stderr.write("row 9: %d comments vs %d instructions\n" % (len(rows), len(ops)))
        return 1
    for index in range(len(rows)):
        blob, offset, text = rows[index]
        addr, oblob, otext = ops[index]
        if offset != addr:
            sys.stderr.write(
                "row 9: offset +%04x is not file +%04x\n" % (offset, addr)
            )
            return 1
        if blob != oblob or text != otext:
            sys.stderr.write("row 9 mismatch %d: %r vs %r\n" % (index, text, otext))
            return 1
    joined = b"".join(blob for blob, _, _ in rows)
    if joined != code:
        sys.stderr.write("row 9: joined %d vs file %d\n" % (len(joined), len(code)))
        return 1
    sys.stdout.write("row 9: %d instructions match\n" % len(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
