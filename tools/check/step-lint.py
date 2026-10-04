#!/usr/bin/env python3
"""Row 18. A bare command in a gate module is red.

Exit codes: 2 usage, 1 a bare command, 99 an unexpected failure.
A line is bare when its first command word is not a shell keyword,
not a function this file defines, and not a gate-lib helper.
step and expect lines are the wrapped form. Heredoc bodies are skipped.
"""

import re
import sys

HELPERS = {
    "die",
    "step",
    "expect",
    "capture_red",
    "sandbox_tree",
    "abs_req",
    "under_tmp",
    "fact",
    "nr_of",
    "carry",
    "payload_rc",
    "payload_body",
}
KEYWORDS = {
    "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done",
    "case", "esac", "in", "function", "select", "time", "coproc", "{", "}",
    "!", "[[", "]]", "[", "]",
}
BUILTINS = {
    "local", "return", "shift", "set", "export", "unset", "trap", "declare",
    "typeset", "readonly", "echo", "printf", "true", "false", ":", "test",
    "read", "mapfile", "readarray", "break", "continue", "let", "eval",
    "exec", "ulimit", "umask", "shopt", "cd", "pwd", "exit", "source", ".",
    "alias", "unalias", "hash", "type", "command", "builtin", "wait", "kill",
    "getopts", "pushd", "popd", "dirs", "caller", "enable", "help", "logout",
    "printf", "read", "umask",
}


def defined_functions(text):
    names = set()
    for line in text.splitlines():
        match = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{?", line)
        if match:
            names.add(match.group(1))
    return names


ASSIGN_VALUE = r"(?:\"[^\"]*\"|'[^']*'|\S+)"
ASSIGN_LINE = re.compile(r"(?:[A-Za-z_][A-Za-z0-9_]*\+?=" + ASSIGN_VALUE + r"\s*)+")
ASSIGN_PREFIX = re.compile(r"^(?:[A-Za-z_][A-Za-z0-9_]*\+?=" + ASSIGN_VALUE + r"\s+)+")


def split_commands(stripped):
    parts = []
    buf = []
    quote = ""
    i = 0
    while i < len(stripped):
        ch = stripped[i]
        if quote:
            buf.append(ch)
            if ch == quote:
                quote = ""
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            buf.append(ch)
            i += 1
            continue
        if stripped.startswith("&&", i) or stripped.startswith("||", i):
            parts.append("".join(buf))
            buf = []
            i += 2
            continue
        if ch in ";&":
            parts.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    parts.append("".join(buf))
    return parts


def command_words(line):
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return []
    if re.match(r"^(step|expect)\b", stripped):
        return []
    words = []
    for chunk in split_commands(stripped):
        chunk = chunk.strip()
        if not chunk:
            continue
        if re.match(r"^[^(]*\)", chunk):
            chunk = re.sub(r"^[^(]*\)\s*", "", chunk, count=1).strip()
            if not chunk or chunk == ";;":
                continue
        if ASSIGN_LINE.fullmatch(chunk):
            continue
        chunk = ASSIGN_PREFIX.sub("", chunk)
        match = re.match(r"([A-Za-z_./][A-Za-z0-9_./-]*)", chunk)
        if match:
            words.append(match.group(1))
        for inner in re.findall(r"\$\((?!<)([^)]*)\)", chunk):
            inner = inner.strip()
            inner = ASSIGN_PREFIX.sub("", inner)
            match = re.match(r"([A-Za-z_./][A-Za-z0-9_./-]*)", inner)
            if match:
                words.append(match.group(1))
    return words


def lint_text(text, allowed):
    hits = []
    heredoc = None
    for lineno, line in enumerate(text.splitlines(), 1):
        if heredoc is not None:
            if line.strip() == heredoc:
                heredoc = None
            continue
        marker = re.search("<<" + "-?" + r"\s*['\"]?([A-Za-z0-9_]+)", line)
        if marker and not re.match(r"^\s*(step|expect)\b", line.strip()):
            heredoc = marker.group(1)
        elif marker and re.match(r"^\s*(step|expect)\b", line.strip()):
            heredoc = marker.group(1)
            continue
        for word in command_words(line):
            base = word.split("/")[-1]
            if base in allowed or word in allowed:
                continue
            hits.append((lineno, word, line.strip()))
            break
    return hits


def main(argv):
    if len(argv) != 1:
        sys.stderr.write("usage: step-lint.py FILE\n")
        return 2
    try:
        text = open(argv[0], encoding="utf-8").read()
    except OSError as exc:
        sys.stderr.write("step-lint: %s\n" % exc)
        return 2
    allowed = set(HELPERS)
    allowed.update(KEYWORDS)
    allowed.update(BUILTINS)
    allowed.update(defined_functions(text))
    hits = lint_text(text, allowed)
    if hits:
        lineno, word, shown = hits[0]
        sys.stdout.write("bare command: %s line %d: %s\n" % (word, lineno, shown))
        return 1
    # A tools script must not rewrite a seed in place.
    write = re.compile(
        r"(^|[^A-Za-z0-9_])(cp|mv|tee|install|dd)\b.*ladder/\S+/hex0([^.]|$)"
    )
    redir = re.compile(r">>?\s*['\"]?\$?[A-Za-z0-9_]*/*ladder/\S+/hex0([^.]|$)")
    for lineno, line in enumerate(text.splitlines(), 1):
        if line.strip().startswith("#"):
            continue
        if write.search(line) or redir.search(line):
            sys.stdout.write("bare command: writes the seed line %d: %s\n" % (lineno, line.strip()))
            return 1
    sys.stdout.write("step-lint: ok\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:
        sys.stderr.write("step-lint: %s\n" % exc)
        sys.exit(99)
