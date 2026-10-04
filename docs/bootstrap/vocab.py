import sys, re, collections
def toks(src):
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c in ' \t\r\n,': i += 1; continue
        if c == ';':
            while i < n and src[i] != '\n': i += 1
            continue
        if c == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == '\\' else 1
            yield ('str', src[i:j+1]); i = j + 1; continue
        if c in '()[]{}': yield ('p', c); i += 1; continue
        j = i
        while j < n and src[j] not in ' \t\r\n,;()[]{}"': j += 1
        yield ('a', src[i:j]); i = j
heads = collections.Counter(); atoms = collections.Counter(); kw = collections.Counter()
nlists = 0
for f in sys.argv[1:]:
    src = open(f).read()
    prev = None
    for t, v in toks(src):
        if prev == ('p', '(') and t == 'a': heads[v] += 1
        if t == 'a':
            atoms[v] += 1
            if v.startswith(':wat::') or v.startswith('wat.'): kw[v] += 1
        if (t, v) == ('p', '('): nlists += 1
        prev = (t, v)
print("files", len(sys.argv)-1, "lists", nlists, "distinct-heads", len(heads))
print("== heads in the wat namespace (the vocabulary wat0 must provide), by count")
for h, c in heads.most_common():
    if h.startswith(':wat::') or h.startswith('wat.'): print(f"{c:7d} {h}")
print("== wat-namespace atoms in NON-head position (types, values, constructors), top 60")
nonhead = {k: kw[k] - heads.get(k, 0) for k in kw}
for k, c in sorted(nonhead.items(), key=lambda x: -x[1])[:60]:
    if c > 0: print(f"{c:7d} {k}")
