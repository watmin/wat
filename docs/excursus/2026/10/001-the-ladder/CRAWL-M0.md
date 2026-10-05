# CRAWL — M0: what stage0's macro prototype does, and what ours must decide

2026-10-04. Read from source this session: the C prototype
`High Level Prototypes/M0-macro.c` in `oriansj/stage0-posix`, fetched from
`raw.githubusercontent.com/oriansj/stage0-posix/master/High%20Level%20Prototypes/M0-macro.c`.
The x86 program `M0_x86.hex2` in `oriansj/stage0-posix-x86` names the same passes in its header comments
(`Tokenize_Line`, `Identify_Macros`, `Line_Macro`, `Process_String`, `Eval_Immediates`). That hex2 file was not
read line by line. Claims about behavior cite the C prototype.

DESIGN already names the rung: a macro assembler, and a mnemonic is a DEFINE that expands to bytes. The directory
is `ladder/3-m0/`. Rule 4 requires the name to be lowercase. Bash remains the sequencer until this rung's brief
exists. This crawl is not that brief.

## What the prototype does

It is a text program. `main` takes one filename, reads it, and writes hex text to stdout. It does not take an
output path and it does not write a binary.

**Tokens.** `Tokenize_Line` skips space, tab, and LF. `#` or `;` starts a comment that runs until CR or LF.
`"` or `'` starts a string that runs until the same quote (`store_string`). Anything else is an atom that runs
until tab, LF, or space (`store_atom`). Atoms and strings are capped at `max_string`, which is 63.

**DEFINE.** `identify_macros` looks for the atom `DEFINE`. It takes the next token as the name and the token
after that as the expression. A string expression drops its first character, the quote. The DEFINE and those two
tokens are unlinked from the list. `line_macro` then walks the later tokens and, on an exact match of the name,
stores that expression on the token. A token already marked as a macro is left alone.

**Strings and numbers.** `process_string` turns a `"` string into hex digits, two per byte (`hexify_string`).
A `'` string's expression is the text after the quote, passed through. `eval_immediates` runs `strtol` on any
other token that has no expression. If the token begins with `0` or the value is not zero, the expression becomes
four hex digits, `%04x`, which is two bytes. Everything else is kept as its own text (`preserve_other`).

**Order.** Tokenize, identify macros, apply them, process strings, evaluate immediates, preserve the rest, print.
`print_hex` skips tokens marked as macros and prints each remaining expression.

## What it does not do

- It links libc: `fopen`, `calloc`, `strtol`, `sprintf`, `fprintf`. Our rungs are syscalls only.
- It always returns success from `main` after a run. A missing argument returns failure. Nothing else is refused.
  A `DEFINE` with no name, a duplicate name, and an unknown name are not refusals.
- `store_atom` stops before a CR, so a CR is not a separator. `purge_lineComment` stops at CR or LF. The two
  disagree.
- The `%04x` immediate is sixteen bits. An x86-64 immediate that needs four bytes does not fit that print.
- Expansion is one token. A mnemonic that should become several hex bytes separated by spaces has to be one
  string, or several tokens that the prototype will not treat as one body.
- The printed text is meant to be read by hex2. Labels, relatives, and raw hex pass through only because
  `preserve_other` copies tokens it does not understand.

## What our ladder already settles

- Rung 3. Built only by hex2. The products are not committed. The gate checks. It does not build.
- The language underneath is hex2's: names that end at whitespace, `%`, `%1`, `%2`, and `&`.
- No libc. Statuses stay total. A new failure gets its own status, the same rule hex1 used.
- The directory is `3-m0` because rule 4 rejects an uppercase name.

## The shape that passes the four questions

M0 reads hex2 plus DEFINE and writes hex2 text. `build` then runs hex2 on that text to get the binary. M0 does
not reimplement labels or relatives.

| Shape | Obvious | Simple | Honest | Good UX |
|---|---|---|---|---|
| Write hex2 text, then let hex2 emit the binary | YES | YES | YES | YES |
| Emit the binary inside M0 | NO | NO | NO | NO |

The second row would copy hex2 into the macro program. The design's "expand to bytes" is the expansion. The
bytes are hex2's job, which is the program we already have.

This is a recommendation. It is not a builder ruling. The README in `ladder/3-m0/` repeats it as the shape the
crawl recommends, and the questions below stay open.

## Asked

- The keyword. The prototype spells it `DEFINE`. Our sources have not needed that word yet.
- What a body may contain. One token, or a quoted run of hex2 text.
- Strings. The prototype uses `"` for bytes and `'` for raw text. Whether we need either, and which quote, is open.
- Immediates. `%04x` is the wrong width for this machine. A number in the source could stay hex2's hex digits
  instead of a decimal immediate. That choice is open.
- A name defined twice, a `DEFINE` with no name, and a use of a name that was never defined.
- Whether a name is expanded inside the body of another DEFINE.
- The build lines. The recommended shape is hex2 on `3-m0`'s hex2-language source, then that product on the M0
  source, writing hex2 text, then hex2 on that text. The filenames are not ruled.
