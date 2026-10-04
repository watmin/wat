"""AST lint for row modules. Text matching is not the check."""

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


def lint_source(text, filename):
    try:
        tree = ast.parse(text, filename=filename)
    except SyntaxError as exc:
        return ["%s:%s: syntax" % (filename, exc.lineno)]
    visitor = RowVisitor()
    visitor.visit(tree)
    return ["%s:%d: %s" % (filename, line, kind) for line, kind in visitor.hits]


def lint_file(path):
    with open(path, encoding="utf-8") as handle:
        return lint_source(handle.read(), path)


def mutant_files(directory):
    """Written in the sandbox. One must be red, one must be accepted."""
    bad = os.path.join(directory, "row_bad.py")
    good = os.path.join(directory, "row_good.py")
    with open(bad, "w", encoding="utf-8") as handle:
        handle.write("def row(obs):\n    if obs:\n        return obs\n")
    with open(good, "w", encoding="utf-8") as handle:
        handle.write("def row(items, ctx):\n    out = []\n    for item in items:\n        out.append(ctx.prove(item))\n    return out\n")
    return bad, good
