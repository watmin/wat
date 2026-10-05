# M0

Usage: `m0 IN OUT`.

Rung 3 of the ladder. Hex2 builds it. This file is the contract. The fixtures in `tests/` are part of it. The machine code belongs to `x86_64-linux`. Bash, the top-level `build`, is the sequencer. It runs hex2's lines, then:

```
out/hex2 ladder/3-m0/x86_64-linux/m0.hex2 out/m0
out/m0 ladder/3-m0/x86_64-linux/m0.m0 out/m0.hex2
out/hex2 out/m0.hex2 out/m0-self
```

`out/m0.hex2` is hex2 text. The gate checks the products. It does not call `build`.

M0 reads hex2's tokens plus lists, and it writes hex2 text. It does not assemble. Hex2 does that. A `(` and a `)` are tokens even when they touch the next word, so `(define ten 0A)` is five tokens. A name is expanded only after its list has been read. A use before that is copied through.

A list has the shape `(define name ...)`. The name is the second word. The words until the closing parenthesis are the body. A body word that is already defined expands to that definition's body. A word that is not defined yet is copied through. M0 writes each resulting token on its own line. `(define SYSCALL 0F 05)` then `(define EXIT SYSCALL)` then a use of `EXIT` writes `0F` and `05` on their own lines. `(define EXIT SYSCALL)` before `SYSCALL` exists, then a use of `EXIT`, writes the word `SYSCALL`. The name is at most 16 bytes. The stored body, counting a newline between tokens, is at most 64 bytes. The table holds 64 definitions. The input is read into 65536 bytes. A longer input is a bad byte.

## Exit status

| exit | meaning |
|---|---|
| 0 | done. OUT holds the hex2 text, mode 0755 |
| 1 | wrong argument count. OUT was not created |
| 2 | IN cannot be opened, or fstat on IN failed |
| 3 | OUT cannot be opened, or is not a regular file, or fchmod failed, or fstat on OUT failed |
| 4 | a bad token: a list that is not `(define name ...)`, a missing `)`, a nested `(`, a stray `)`, a name longer than 16 bytes, a stored body longer than 64 bytes, a 65th definition, an input longer than 65536 bytes, or a cycle where a name in a body expands back into the definition being read. OUT holds the text already written, mode 0755 |
| 6 | a read, write, close, or truncate failed |
| 7 | IN and OUT are the same file |
| 9 | a name defined twice. OUT holds the text already written, mode 0755 |

Statuses 5, 8, 10, and 11 are not produced by this program. Hex2 still owns them.

## Fixtures

`plain.m0` is `41 42` and a newline. The text is `41`, a newline, `42`, and a newline. Hex2 assembles either spelling to the bytes `41 42`.

`define-ten.m0` is `(define ten 0A)` and then the name. The text is `0A` and a newline. Hex2 assembles that to one byte, `0A`.

`compose.m0` defines `SYSCALL` as `0F 05`, defines `EXIT` as `SYSCALL`, and uses `EXIT`. The text is `0F`, a newline, `05`, and a newline. `early.m0` defines `EXIT` as `SYSCALL` before `SYSCALL` exists, then uses `EXIT`. The text is the word `SYSCALL` and a newline.

`dup.m0` defines `ten` twice. The status is 9 and OUT is empty. `missing.m0` is `(define ten)` with no body. The status is 4 and OUT is empty. `cycle.m0` defines `a` as `b` and `b` as `a`. The status is 4 and OUT is empty.

## Asked

A quoted string and a decimal immediate are not in this increment.
