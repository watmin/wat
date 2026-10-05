# M0

Usage: `m0 IN OUT`.

Rung 3 of the ladder. Hex2 builds it. This file is the contract. The fixtures in `tests/` are part of it. The machine code belongs to `x86_64-linux`. Bash, the top-level `build`, is the sequencer. It runs hex2's lines, then:

```
out/hex2 ladder/3-m0/x86_64-linux/m0.hex2 out/m0
out/m0 ladder/3-m0/x86_64-linux/m0.m0 out/m0.hex2
out/hex2 out/m0.hex2 out/m0-self
```

`out/m0.hex2` is hex2 text. The gate checks the products. It does not call `build`.

M0 reads hex2's language plus one form, and it writes hex2 text. It does not assemble. Hex2 does that. A name is expanded only after its `DEFINE` has been read. A use before that is copied through.

`DEFINE` is followed by a name and one body token. The name is at most 16 bytes. The body is at most 64 bytes. The table holds 64 definitions. The input is read into 65536 bytes. A longer input is a bad byte.

## Exit status

| exit | meaning |
|---|---|
| 0 | done. OUT holds the hex2 text, mode 0755 |
| 1 | wrong argument count. OUT was not created |
| 2 | IN cannot be opened, or fstat on IN failed |
| 3 | OUT cannot be opened, or is not a regular file, or fchmod failed, or fstat on OUT failed |
| 4 | a bad token: `DEFINE` without a name or a body, a name longer than 16 bytes, a body longer than 64 bytes, a 65th definition, or an input longer than 65536 bytes. OUT holds the text already written, mode 0755 |
| 6 | a read, write, close, or truncate failed |
| 7 | IN and OUT are the same file |
| 9 | a name defined twice. OUT holds the text already written, mode 0755 |

Statuses 5, 8, 10, and 11 are not produced by this program. Hex2 still owns them.

## Fixtures

`plain.m0` is `41 42` and a newline. The text is `41`, a newline, `42`, and a newline. Hex2 assembles either spelling to the bytes `41 42`.

`define-ten.m0` defines `ten` as `0A` and then uses it. The text is `0A` and a newline. Hex2 assembles that to one byte, `0A`.

`dup.m0` defines `ten` twice. The status is 9 and OUT is empty. `missing.m0` is `DEFINE` and a name with no body. The status is 4 and OUT is empty.

## Asked

A quoted string, a decimal immediate, and expansion of a name inside another definition's body are not in this increment.
