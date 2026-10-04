"""AST lint for row functions. Text matching is not the check."""

import ast
import os


class RowVisitor(ast.NodeVisitor):
    def __init__(self):
        self.hits = []

    def visit_If(self, node):
        self.hits.append((node.lineno, "if"))

    def visit_IfExp(self, node):
        self.hits.append((node.lineno, "if"))

    def visit_Assert(self, node):
        self.hits.append((node.lineno, "assert"))

    def visit_Compare(self, node):
        self.hits.append((node.lineno, "comparison"))

    def visit_BoolOp(self, node):
        names = []
        for value in node.values:
            if isinstance(value, ast.Name) and value.id in ("obs", "observation"):
                names.append(value.id)
            if isinstance(value, ast.Attribute):
                names.append("attribute")
        if names:
            self.hits.append((node.lineno, "boolean on an observation"))
        self.generic_visit(node)


def _call_name(node):
    func = node.func
    if isinstance(func, ast.Name):
        return func.id
    if isinstance(func, ast.Attribute):
        return func.attr
    return ""


def _computed_bool(node):
    for child in ast.walk(node):
        if isinstance(child, (ast.IfExp, ast.Compare, ast.BoolOp)):
            return True
    return False


def lint_source(text, filename):
    try:
        tree = ast.parse(text, filename=filename)
    except SyntaxError as exc:
        return ["%s:%s: syntax" % (filename, exc.lineno)]
    hits = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("row_"):
            visitor = RowVisitor()
            for stmt in node.body:
                visitor.visit(stmt)
            for line, kind in visitor.hits:
                hits.append("%s:%d: %s" % (filename, line, kind))
        if isinstance(node, ast.Call) and _call_name(node) in ("_static", "Observation"):
            if _computed_bool(node):
                hits.append("%s:%d: observation from a computed boolean" % (filename, node.lineno))
    return hits


def lint_file(path):
    with open(path, encoding="utf-8") as handle:
        return lint_source(handle.read(), path)


def lint_gate(root):
    hits = []
    base = os.path.join(root, "tools", "gate")
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = sorted(name for name in dirnames if name != "__pycache__")
        for filename in sorted(filenames):
            if filename.endswith(".py"):
                hits.extend(lint_file(os.path.join(dirpath, filename)))
    return hits


def mutant_files(directory):
    """Written in the sandbox. The if and the boolean wrapper are red. The loop is accepted."""
    bad = os.path.join(directory, "row_bad.py")
    good = os.path.join(directory, "row_good.py")
    static = os.path.join(directory, "row_static.py")
    with open(bad, "w", encoding="utf-8") as handle:
        handle.write("def row_bad(obs):\n    if obs:\n        return obs\n")
    with open(good, "w", encoding="utf-8") as handle:
        handle.write(
            "def row(items, ctx):\n    out = []\n    for item in items:\n        out.append(ctx.prove(item))\n    return out\n"
        )
    with open(static, "w", encoding="utf-8") as handle:
        handle.write("def row_static(a, b):\n    return _static(0 if a == b else 1)\n")
    return bad, good, static
