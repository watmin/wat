"""Layout rules are functions over a tree. Each refusal text is that rule's own."""

import os
import re
import subprocess

TOP = {
    "README.md", "LICENSE", "NOTICE", ".gitignore", ".gitattributes",
    "build", "ladder", "tools", "docs", "brand", "archived", "out",
}
STANDING = {"LAYOUT.md", "WARDS.md", "MACHINE.md", "RECOVERY.md"}
# The one quoted demonstration of the bare form. Declared in LAYOUT.
BARE_EXEMPT = {
    ("docs/excursus/2026/10/001-the-ladder/WEIGH-hex0.md", 1462),
    ("docs/excursus/2026/10/001-the-ladder/WEIGH-hex0.md", 2310),
}
BARE = re.compile(r"(^|[^A-Za-z0-9_])(excursus|arc)[ \t]+[0-9]+", re.I)
STATUS_WORD = re.compile(r"status", re.I)
STATUS_ROW = re.compile(r"\|\s*[0-9]+\s*\|")
POINTER = "the rung README"


def git_run(argv):
    env = os.environ.copy()
    for key in list(env):
        if key.startswith("GIT_"):
            del env[key]
    env["GIT_CONFIG_GLOBAL"] = "/dev/null"
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    env["GIT_OPTIONAL_LOCKS"] = "0"
    cmd = [argv[0], "-c", "diff.autoRefreshIndex=false", *argv[1:]]
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)


def fail(rule, text):
    raise LayoutError("layout: rule %s: %s" % (rule, text))


class LayoutError(Exception):
    pass


def check(root, git):
    rule1(root)
    rule2(root)
    names = in_hand(root)
    rule3(root, names)
    rule4(root)
    rule5(root)
    rule6(root, git)
    rule8(root)
    rule9(root)
    return "layout: ok"


def in_hand(root):
    """Names whose DESIGN row says the machine is in hand."""
    path = os.path.join(root, "docs/excursus/2026/10/001-the-ladder/DESIGN-the-ladder.md")
    text = open(path, encoding="utf-8").read().splitlines()
    found = []
    for line in text:
        if not line.startswith("| `"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 4:
            continue
        name = cells[0].strip("`")
        hand = cells[3].strip().lower()
        if hand == "yes":
            found.append(name)
    if "x86_64-linux" not in found:
        fail(3, "no in-hand target")
    return found


def rule1(root):
    for name in os.listdir(root):
        if name == ".git":
            continue
        if name not in TOP:
            fail(1, "top-level name not in the layout: %s" % name)
    if os.path.isdir(os.path.join(root, ".git")) or os.path.isfile(os.path.join(root, ".git")):
        listed = git_run(["git", "-C", root, "ls-files", "-z", "--", "out"])
        if listed.returncode == 0 and listed.stdout.strip(b"\0"):
            fail(1, "tracked out/ path: %s" % listed.stdout.split(b"\0")[0].decode())
    brand = os.path.join(root, "brand")
    if os.path.isdir(brand):
        for dirpath, dirnames, filenames in os.walk(brand):
            for filename in filenames:
                path = os.path.join(dirpath, filename)
                data = open(path, "rb").read()
                if not image_bytes(data):
                    fail(1, "brand/ holds a non-image: %s" % os.path.relpath(path, root))
                if b"\x7fELF" in data:
                    fail(1, "brand/ holds ELF magic: %s" % os.path.relpath(path, root))


def image_bytes(data):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return True
    if data[:4] == b"\x00\x00\x01\x00":
        return True
    head = data[:200].lstrip().lower()
    return head.startswith(b"<svg") or b"<svg" in head


def rule2(root):
    seed = os.path.join(root, "ladder/0-hex0/x86_64-linux/hex0")
    for dirpath, dirnames, filenames in os.walk(root):
        base = os.path.basename(dirpath)
        if base == ".git":
            dirnames[:] = []
            continue
        if os.path.relpath(dirpath, root) == "out" or os.path.relpath(dirpath, root).startswith("out" + os.sep):
            dirnames[:] = []
            continue
        for filename in filenames:
            path = os.path.join(dirpath, filename)
            rel = os.path.relpath(path, root)
            if rel == os.path.join("ladder", "0-hex0", "x86_64-linux", "hex0"):
                continue
            data = open(path, "rb").read()
            if data.startswith(b"\x7fELF"):
                fail(2, "ELF magic outside the seed: %s" % rel)
            if b"\x00" in data and not rel.startswith("brand" + os.sep) and rel != "brand":
                if not rel.startswith("brand/"):
                    fail(2, "binary outside the seed and brand/: %s" % rel)


def rule3(root, names):
    ladder = os.path.join(root, "ladder")
    for rung in os.listdir(ladder):
        path = os.path.join(ladder, rung)
        if not os.path.isdir(path):
            continue
        for name in os.listdir(path):
            if name in ("README.md", "tests"):
                continue
            target = os.path.join(path, name)
            if not os.path.isdir(target):
                fail(3, "rung holds something other than README, tests/, and a target: %s/%s" % (rung, name))
            if name not in names:
                fail(3, "target not in hand: %s" % name)
            held = os.listdir(target)
            if "hex0.hex0" not in held and rung.startswith("0-"):
                fail(3, "target has no source: %s" % name)


def rule4(root):
    ladder = os.path.join(root, "ladder")
    numbers = []
    for name in os.listdir(ladder):
        if not os.path.isdir(os.path.join(ladder, name)):
            continue
        match = re.fullmatch(r"([0-9]+)-[a-z][a-z0-9]*", name)
        if not match:
            fail(4, "rung directory is not <n>-<name>: %s" % name)
        numbers.append(int(match.group(1)))
    numbers.sort()
    for index, number in enumerate(numbers):
        if number != index:
            fail(4, "rung numbers skip %d" % index)


def rule5(root):
    readme = os.path.join(root, "ladder/0-hex0/README.md")
    text = open(readme, encoding="utf-8").read()
    if "| 0 |" not in text or "| 7 |" not in text:
        fail(5, "readme has no exit statuses: 0-hex0")
    source_status(os.path.join(root, "ladder/0-hex0/x86_64-linux/hex0.hex0"))
    hex1_readme(root)
    hex2_readme(root)
    m0_readme(root)
    wat0_readme(root)


def hex1_readme(root):
    path = os.path.join(root, "ladder/1-hex1/README.md")
    if not os.path.isfile(path):
        return
    text = open(path, encoding="utf-8").read()
    if "| 0 |" not in text or "| 11 |" not in text:
        fail(5, "readme has no exit statuses: 1-hex1")


def hex2_readme(root):
    path = os.path.join(root, "ladder/2-hex2/README.md")
    if not os.path.isfile(path):
        return
    text = open(path, encoding="utf-8").read()
    if "| 0 |" not in text or "| 11 |" not in text:
        fail(5, "readme has no exit statuses: 2-hex2")


def m0_readme(root):
    path = os.path.join(root, "ladder/3-m0/README.md")
    if not os.path.isfile(path):
        return
    text = open(path, encoding="utf-8").read()
    if "| 0 |" not in text or "| 9 |" not in text:
        fail(5, "readme has no exit statuses: 3-m0")


def wat0_readme(root):
    path = os.path.join(root, "ladder/4-wat0/README.md")
    if not os.path.isfile(path):
        return
    text = open(path, encoding="utf-8").read()
    if "| 0 |" not in text or "| 9 |" not in text:
        fail(5, "readme has no exit statuses: 4-wat0")


def rule6(root, git):
    proc = git_run([git, "-C", root, "diff", "--quiet", "c45603e", "--", "archived"])
    if proc.returncode != 0:
        fail(6, "archived/ bytes differ from c45603e")


def rule8(root):
    """The symbol rule is stated in LAYOUT. This scan is the colon-path check that rule keeps."""
    pair = ":" + ":"
    left = "<" + "-"
    right = "-" + ">"
    tools = os.path.join(root, "tools")
    for dirpath, dirnames, filenames in os.walk(tools):
        if os.path.basename(dirpath) == "__pycache__":
            continue
        for filename in filenames:
            path = os.path.join(dirpath, filename)
            rel = os.path.relpath(path, root)
            for lineno, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
                if pair in line:
                    fail(8, "colon-path token in %s:%d" % (rel, lineno))
                if bare_arrow(line, left, right):
                    fail(8, "bare type arrow in %s:%d" % (rel, lineno))


def bare_arrow(line, left, right):
    for token in (left, right):
        start = 0
        while True:
            at = line.find(token, start)
            if at < 0:
                break
            before = line[at - 1] if at else " "
            after = line[at + len(token)] if at + len(token) < len(line) else " "
            if not (before.isalnum() or before == "_") and not (after.isalnum() or after == "_"):
                return True
            start = at + len(token)
    return False


def rule9(root):
    docs = os.path.join(root, "docs")
    for name in os.listdir(docs):
        path = os.path.join(docs, name)
        if name == "excursus" and os.path.isdir(path):
            continue
        if not (name.endswith(".md") and os.path.isfile(path)):
            fail(9, "docs/ top level is not a standing document: %s" % name)
        if name not in STANDING and name != "excursus":
            # standing set is the known list; other md files at the top are red
            if not name.endswith(".md"):
                fail(9, "docs/ top level is not a standing document: %s" % name)
    # Any extra top-level md that is not standing is red.
    for name in os.listdir(docs):
        if name.endswith(".md") and name not in STANDING:
            fail(9, "docs/ top level is not a standing document: %s" % name)
    walk_excursus(root)
    scan_bare(root)


def walk_excursus(root):
    base = os.path.join(root, "docs/excursus")
    if not os.path.isdir(base):
        return
    for year in sorted(os.listdir(base)):
        ypath = os.path.join(base, year)
        if not re.fullmatch(r"[0-9]{4}", year) or not os.path.isdir(ypath):
            fail(9, "excursus year is not YYYY: %s" % year)
        for month in sorted(os.listdir(ypath)):
            mpath = os.path.join(ypath, month)
            if not re.fullmatch(r"0[1-9]|1[0-2]", month) or not os.path.isdir(mpath):
                fail(9, "excursus month is not MM: %s/%s" % (year, month))
            counters = []
            for entry in sorted(os.listdir(mpath)):
                epath = os.path.join(mpath, entry)
                match = re.fullmatch(r"([0-9]{3})-([a-z][a-z0-9]*(-[a-z][a-z0-9]*)*)", entry)
                if not match or not os.path.isdir(epath):
                    fail(9, "badly formed excursus slug: %s/%s/%s" % (year, month, entry))
                counters.append(int(match.group(1)))
                for inner in os.listdir(epath):
                    ipath = os.path.join(epath, inner)
                    if os.path.isdir(ipath):
                        fail(9, "excursus holds a directory: %s/%s/%s/%s" % (year, month, entry, inner))
                    if not inner.endswith(".md"):
                        fail(9, "excursus holds a non-document: %s/%s/%s/%s" % (year, month, entry, inner))
            expect = 1
            for number in sorted(counters):
                if number != expect:
                    fail(9, "excursus counter gap: %s/%s missing %03d" % (year, month, expect))
                expect += 1


def scan_bare(root):
    docs = os.path.join(root, "docs")
    for dirpath, dirnames, filenames in os.walk(docs):
        for filename in filenames:
            if not filename.endswith(".md"):
                continue
            path = os.path.join(dirpath, filename)
            rel = os.path.relpath(path, root)
            for lineno, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
                if (rel, lineno) in BARE_EXEMPT:
                    continue
                if BARE.search(line):
                    fail(9, "bare numbered reference in %s:%d" % (rel, lineno))


def source_status(path):
    """Rule 5's needle, on one target source."""
    for lineno, line in enumerate(open(path, encoding="utf-8"), 1):
        if POINTER in line and "status" not in line.lower():
            continue
        if STATUS_WORD.search(line) or STATUS_ROW.search(line):
            fail(5, "target source states a status meaning: %s:%d" % (os.path.basename(path), lineno))


def prove_mutants(scratch):
    """Each rule's own needle, through the same function the live tree uses."""
    one(scratch, "rule 1", "top-level name not in the layout: STRAY", _mut_stray)
    one(scratch, "rule 1 image", "brand/ holds a non-image:", _mut_brand_text)
    one(scratch, "rule 1 elf", "brand/ holds ELF magic:", _mut_brand_elf)
    one(scratch, "rule 2", "binary outside the seed and brand/:", _mut_nul)
    one(scratch, "rule 3", "rung holds something other than README, tests/, and a target:", _mut_brief)
    one(scratch, "rule 5 Status", "target source states a status meaning:", lambda d: _mut_status(d, "Status 4: done\n"))
    one(scratch, "rule 5 EXIT", "target source states a status meaning:", lambda d: _mut_status(d, "EXIT STATUS: 4\n"))
    one(scratch, "rule 5 colon", "target source states a status meaning:", lambda d: _mut_status(d, "status: 4\n"))
    one(scratch, "rule 5 eq", "target source states a status meaning:", lambda d: _mut_status(d, "status=4\n"))
    one(scratch, "rule 5 table", "target source states a status meaning:", lambda d: _mut_status(d, "| 4 |\n"))
    one(scratch, "rule 5 hex1", "readme has no exit statuses: 1-hex1", _mut_hex1_readme)
    one(scratch, "rule 5 hex2", "readme has no exit statuses: 2-hex2", _mut_hex2_readme)
    one(scratch, "rule 5 m0", "readme has no exit statuses: 3-m0", _mut_m0_readme)
    one(scratch, "rule 5 wat0", "readme has no exit statuses: 4-wat0", _mut_wat0_readme)
    one(scratch, "rule 8 colon", "colon-path token in", _mut_colon)
    one(scratch, "rule 8 arrow", "bare type arrow in", _mut_arrow)
    one(scratch, "rule 9", "badly formed excursus slug:", _mut_slug)
    _mut_exit_zero()
    return "layout mutants: red"


def one(scratch, label, needle, build):
    path = os.path.join(scratch, label.replace(" ", "-"))
    if os.path.exists(path):
        import shutil
        shutil.rmtree(path)
    os.makedirs(path)
    try:
        build(path)
    except LayoutError as exc:
        if needle not in str(exc):
            fail(0, "mutant %s refused without its needle: %s" % (label, exc))
        return
    fail(0, "mutant %s stayed green" % label)


def _mut_stray(path):
    open(os.path.join(path, "STRAY"), "w", encoding="utf-8").write("x\n")
    rule1(path)


def _mut_brand_text(path):
    os.makedirs(os.path.join(path, "brand"))
    open(os.path.join(path, "brand", "x.md"), "w", encoding="utf-8").write("x\n")
    for name in TOP:
        if name in ("brand", "out"):
            continue
        open(os.path.join(path, name), "w", encoding="utf-8").write("x\n")
    rule1(path)


def _mut_brand_elf(path):
    os.makedirs(os.path.join(path, "brand"))
    open(os.path.join(path, "brand", "evil.png"), "wb").write(b"\x89PNG\r\n\x1a\n\x7fELF")
    for name in TOP:
        if name in ("brand", "out"):
            continue
        open(os.path.join(path, name), "w", encoding="utf-8").write("x\n")
    rule1(path)


def _mut_nul(path):
    os.makedirs(os.path.join(path, "tools"))
    open(os.path.join(path, "tools", "x"), "wb").write(b"A\x00B")
    rule2(path)


def _mut_brief(path):
    os.makedirs(os.path.join(path, "ladder", "0-hex0"))
    open(os.path.join(path, "ladder", "0-hex0", "BRIEF.md"), "w", encoding="utf-8").write("x\n")
    rule3(path, ["x86_64-linux"])


def _mut_hex1_readme(path):
    os.makedirs(os.path.join(path, "ladder", "1-hex1"))
    open(os.path.join(path, "ladder", "1-hex1", "README.md"), "w", encoding="utf-8").write("| 0 |\n")
    hex1_readme(path)


def _mut_hex2_readme(path):
    os.makedirs(os.path.join(path, "ladder", "2-hex2"))
    open(os.path.join(path, "ladder", "2-hex2", "README.md"), "w", encoding="utf-8").write("| 0 |\n")
    hex2_readme(path)


def _mut_m0_readme(path):
    os.makedirs(os.path.join(path, "ladder", "3-m0"))
    open(os.path.join(path, "ladder", "3-m0", "README.md"), "w", encoding="utf-8").write("| 0 |\n")
    m0_readme(path)


def _mut_wat0_readme(path):
    os.makedirs(os.path.join(path, "ladder", "4-wat0"))
    open(os.path.join(path, "ladder", "4-wat0", "README.md"), "w", encoding="utf-8").write("| 0 |\n")
    wat0_readme(path)


def _mut_status(path, text):
    name = os.path.join(path, "hex0.hex0")
    open(name, "w", encoding="utf-8").write(text)
    source_status(name)


def _mut_colon(path):
    os.makedirs(os.path.join(path, "tools"))
    token = ":" + ":"
    open(os.path.join(path, "tools", "bad"), "w", encoding="utf-8").write("wat" + token + "core\n")
    rule8(path)


def _mut_arrow(path):
    os.makedirs(os.path.join(path, "tools"))
    open(os.path.join(path, "tools", "bad"), "w", encoding="utf-8").write("a " + "-" + "> b\n")
    rule8(path)


def _mut_slug(path):
    os.makedirs(os.path.join(path, "docs", "excursus", "2026", "10", "not-a-slug"))
    walk_excursus(path)


def _mut_exit_zero():
    from tools.gate.observe import Expect, Observation, prove
    obs = Observation(status=0, stdout=b"layout: rule 1: top-level name not in the layout: STRAY\n")
    verdict = prove(Expect("layout exit 0", status=1, stdout_has=b"layout: rule 1:"), obs)
    if verdict.ok:
        fail(1, "exit 0 with the needle stayed green")


def hash_visible(root):
    import hashlib
    digest = hashlib.sha256()
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [name for name in sorted(dirnames) if name not in (".git", "out")]
        for filename in sorted(filenames):
            path = os.path.join(dirpath, filename)
            rel = os.path.relpath(path, root)
            if rel == "out" or rel.startswith("out/"):
                continue
            digest.update(rel.encode())
            with open(path, "rb") as handle:
                digest.update(handle.read())
    return digest.hexdigest()
