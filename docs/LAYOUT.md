# LAYOUT — where everything lives, enforced

The builder, 2026-10-03: *"we've been burned many times working on holon and wat with letting llms run wild... we just
need to be mindful"*. Mindfulness alone is a convention, and conventions rot. So this layout is CHECKED:
`tools/layout.sh` runs first in `tools/verify.sh`. That command, with no argument, is the fast tier: every edit and
every executor strike. It runs every check except row-proof, and its final line names the skip (`row-proof not run`).
`tools/verify.sh --prove` runs those checks plus row-proof, and its final line says `proved`. A checkpoint, a landing,
and vigilia require `--prove`. The flag is the only switch. An unknown argument is refused. A file in the wrong place,
or written in a retired syntax, is red when either tier runs. There is no CI. To change the layout, amend this
document and the gate together, in one commit, on purpose.

```
wat/
  README.md  LICENSE  NOTICE  .gitignore  .gitattributes
  ladder/               the bootstrap, one directory per rung, in build order
    0-hex0/             README.md (the contract) · tests/ (contract fixtures, shared by every target)
      x86_64-linux/     hex0.hex0 (source, in this target's code) · hex0 (the seed for this target)
    1-hex1/ …           each rung: README.md · tests/ · one <arch>-<os>/ per target, holding its source
  tools/                CHECKS only, never builds a rung (one declared exception: the seed, below): verify.sh, layout.sh, check/
  docs/                 standing documents at the top (LAYOUT, WARDS, MACHINE, RECOVERY); everything else in an excursus
    excursus/YYYY/MM/NNN-<slug>/   one excursus: its design, crawls, briefs, expectations, scores, weighs
  brand/                the logo and icons, image files only, copied verbatim from watmin/algebraic-intelligence.dev
  archived/             frozen: the 2024–26 repository
  out/                  build output: gitignored, never committed
```

## The rules `tools/layout.sh` enforces

1. **The top level is exactly the list above.** Every name on disk at the top, except `.git`. `README.md`, `LICENSE`, `NOTICE`, `.gitignore`, `.gitattributes`,
   `ladder/`, `tools/`, `docs/`, `brand/` and `archived/` are allowed; `out/` may exist but is never tracked. The compiler's home is its rung, when that rung exists. A
   tracked path under `out/` is a red. Any other top-level name is a red. The image-only check on `brand/` is
   part of this rule: a file there must be a PNG, ICO or SVG by its bytes, and no file there may contain ELF magic.
2. **One committed binary per target: `ladder/0-hex0/<arch>-<os>/hex0`.** This rule is about binaries a rung produces.
   ELF magic (`7F 45 4C 46`) anywhere else, including `brand/`, is a red. A NUL byte anywhere else except `brand/` is a
   red: `brand/` holds images, which are binaries on purpose, and only the NUL check is exempt there. The fault injector
   is not a rung binary. The contract builds it in the sandbox under `/var/tmp`.
3. **A rung directory holds code, never process.** `ladder/<n>-<name>/` contains `README.md` (the contract, one per
   rung), `tests/` (contract fixtures, shared by every target), and one directory per target named `<arch>-<os>` in
   `uname` spelling (`x86_64-linux`, `aarch64-linux`). A target directory holds that target's source, plus the seed in
   rung 0, and may hold `*.tsv` tables the gate reads (`syscalls.tsv`, `gate.tsv`). A rung is one contract with
   per-target implementations: a new architecture or OS lands as a new target directory and is held to the same README
   and the same tests. Briefs, expectations, scores and notes live in `docs/`.
4. **Rung directories are numbered in build order.** `<n>-<name>`, where `n` counts from 0 with no gaps. Rung `n` is
   built only by rung `n-1`. Rung 0, the seed, is the one declared exception: each target's seed was decoded ONCE from its commented
   hex by `tools/check/hex-check.py`, and from then on it reproduces itself byte for byte from that source (the
   fixpoint, checked on every verify). That decode is the bootstrap of the root of trust, and the only RUNG build any tool
   ever performs.
5. **Every rung's `README.md` states its contract:** its input language, what it outputs, and every exit status. The
   README's status numbers are the contract. A target source that states a status meaning is red: the words `Exit status:` or `status` and a digit. A pointer that names the README and states no status meaning stays green.
6. **`archived/` is frozen.** Its tracked files must equal the list at `c45603e`, the archive commit, byte for byte.
7. **`tools/` checks; it never builds a rung.** Every file under `tools/` that is not git-ignored. The seed decode in rule 4 is the one exception. No script under
   `tools/` may write a rung's output into `out/`, including a quoted path, a variable path, or a write of a target seed. `out/` holds only what a rung produces when the gate runs it (for
   example, the seed decoding its own source). A check's own scratch and instruments (the fault injector built by
   `gcc` into the sandbox, staged OUT files, the copied tree the layout mutants run on) live under `/var/tmp`, never
   in the repository. Every instrument a check needs is built from tracked source during the run: the gate depends on
   nothing outside the repository.
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
