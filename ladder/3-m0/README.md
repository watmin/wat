# M0

Rung 3 of the ladder. Hex2 builds it. This file is the contract shell. The crawl is
`docs/excursus/2026/10/001-the-ladder/CRAWL-M0.md`. The machine code belongs to `x86_64-linux`. Bash, the
top-level `build`, is the sequencer until this rung's brief. `build` does not run this rung yet. The gate does
not call `build`.

No source is in the tree. No fixture is in the tree.

## The shape the crawl recommends

M0 reads hex2's language plus a macro, and it writes hex2 text. A mnemonic is a name defined to expand to hex2
text. `build` then runs hex2 on that text to get the binary. M0 does not reimplement names, `%`, `%1`, `%2`, or
`&`. That shape passes the four questions in the crawl. It is not a builder ruling yet.

Statuses 0–11 stay hex2's until a macro failure needs a new number. A number past 11 is unruled. The words for
0–11 are in `ladder/2-hex2/README.md`.

## Asked

- The keyword that introduces a definition.
- Whether the body is one token or a quoted run of hex2 text.
- Whether a quoted string is in this rung, and which quote.
- Whether a decimal immediate exists, and how wide it is. The stage0 prototype prints four hex digits.
- What status a second definition, a definition with no name, and a use of an undefined name take.
- Whether a name is expanded inside another definition's body.
- The filenames and the build lines.
