# LAYOUT — where everything lives, enforced

The builder, 2026-10-03: *"we've been burned many times working on holon and wat with letting llms run wild... we just
need to be mindful"*. Mindfulness alone is a convention, and conventions rot. So this layout is CHECKED:
`tools/layout.sh` runs first in `tools/verify.sh`, and a file in the wrong place, or written in a retired syntax, is
a red build. To change the layout,
amend this document and the gate together, in one commit, on purpose.

```
wat/
  README.md  LICENSE  NOTICE  .gitignore  .gitattributes
  ladder/               the bootstrap, one directory per rung, in build order
    0-hex0/             README.md · hex0.hex0 (source) · hex0 (THE seed binary) · tests/
    1-hex1/ …           each rung: README.md · its source, in the language of the rung below · tests/
  watc/                 the compiler, when the ladder reaches it
  tools/                CHECKS only, never builds a rung (one declared exception: the seed, below): verify.sh, layout.sh, check/
  docs/                 standing documents at the top (LAYOUT, WARDS, MACHINE); everything else in an excursus
    excursus/YYYY/MM/NNN-<slug>/   one excursus: its design, crawls, briefs, expectations, scores, weighs
  brand/                the logo and icons, image files only, copied verbatim from watmin/algebraic-intelligence.dev
  archived/             frozen: the 2024–26 repository
  out/                  build output: gitignored, never committed
```

## The rules `tools/layout.sh` enforces

1. **The top level is exactly the list above.** `README.md`, `LICENSE`, `NOTICE`, `.gitignore`, `.gitattributes`,
   `ladder/`, `watc/`, `tools/`, `docs/`, `brand/` and `archived/` are allowed; `out/` may exist but is never tracked. Any other
   tracked top-level name is a red.
2. **One committed binary: `ladder/0-hex0/hex0`.** A tracked file anywhere else that begins with the ELF magic
   (`7F 45 4C 46`) is a red. Every other binary is built into `out/`.
3. **A rung directory holds code, never process.** `ladder/<n>-<name>/` contains `README.md`, its source files and
   `tests/`. Briefs, expectations, scores and notes live in `docs/`.
4. **Rung directories are numbered in build order.** `<n>-<name>`, where `n` counts from 0 with no gaps. Rung `n` is
   built only by rung `n-1`. Rung 0, the seed, is the one declared exception: it was decoded ONCE from its commented
   hex by `tools/check/hex-check.py`, and from then on it reproduces itself byte for byte from that source (the
   fixpoint, checked on every verify). That decode is the bootstrap of the root of trust, and the only build any tool
   ever performs.
5. **Every rung's `README.md` states its contract:** its input language, what it outputs, and every exit status.
6. **`archived/` is frozen.** Its tracked files must equal the list at `c45603e`, the archive commit, byte for byte.
7. **`tools/` checks; it never builds.** No rung's output in `out/` may be produced by anything under `tools/`.
8. **Only Clojure/EDN-compliant syntax.** No tracked file outside `archived/` and `docs/` contains a token with `::`
   (a colon path such as `:wat::core::+`), or a bare `<-` or `->` used as a type annotation. Names are namespaced
   symbols (`wat.core/+`), and types are ascribed with `:-`. The builder, 2026-10-04: *"we are not going to support
   any of the non-clojure/edn compliant syntax... our new tooling must not inherit any of this syntax... if there's
   any doubts... ask me"*. A spelling that is not settled is asked about, never guessed.
9. **`docs/` has one shape.** Its top level holds only standing documents (`*.md`) and the directory `excursus/`.
   Every excursus is `docs/excursus/YYYY/MM/NNN-<slug>/`. The counter `NNN` is three digits, starts at `001` in each
   month and has no gaps, and `<slug>` is lowercase words joined by `-`. An excursus directory holds documents only:
   no source, no fixtures, no binaries. Those live in their rung. The builder, 2026-10-04: *"i prefer monthly
   resolution with new counters per month... we use excursus instead of arc"*.
   **An excursus is referred to by its full `YYYY/MM/NNN-<slug>`**, or by its whole slug where the date is plain from
   context, in documents, comments, commit messages and names. Never by a bare number (the name, a space, then digits): the
   counter restarts every month, so a bare number is ambiguous by design. The builder, 2026-10-04: *"wat-rs docs kept
   using 'arc NNN' and it got messy.... my preference is the time stamp in comments and names"*.
