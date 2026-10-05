# wat0

Usage: `wat0 IN OUT`.

Rung 4 of the ladder. M0 builds its hex2 text and hex2 emits the binary. This file is the contract. The fixtures in `tests/` are part of it. The machine code belongs to `x86_64-linux`. Bash, the top-level `build`, is the sequencer. It runs M0's lines, then:

```
out/m0 ladder/4-wat0/x86_64-linux/wat0.m0 out/wat0.hex2
out/hex2 out/wat0.hex2 out/wat0
out/hex2 ladder/4-wat0/x86_64-linux/wat0.hex2 out/wat0-self
```

`out/wat0.hex2` is hex2 text. The gate checks the products. It does not call `build`.

wat0 reads a wat program and writes the decimal value of `u/main`, then a newline. The heap is an arena that never frees. A `wat.core/let` binding is visible to the bindings after it, and the arena does not give that storage back. This increment reads these forms: `wat.core/defn`, an empty parameter list, an optional `:-` and a type name, one body expression, integer literals, names, `wat.core/let`, and `wat.core/+`. The entry is `u/main`. A `;` comment runs to the next newline.

## Exit status

| exit | meaning |
|---|---|
| 0 | done. OUT holds the decimal and a newline, mode 0755 |
| 1 | wrong argument count. OUT was not created |
| 2 | IN cannot be opened, or fstat on IN failed |
| 3 | OUT cannot be opened, or is not a regular file, or fchmod failed, or fstat on OUT failed |
| 4 | a bad form, a missing `u/main`, or a name that is not bound. OUT holds the text already written, mode 0755 |
| 6 | a read, write, close, or truncate failed, or the arena is full |
| 7 | IN and OUT are the same file |
| 9 | `u/main` defined twice. OUT holds the text already written, mode 0755 |

## Fixtures

`forty-two.wat` binds `x` to 40 and adds 2. The text is `42` and a newline. `seven.wat` is the literal 7. The text is `7` and a newline. `bad.wat` has no body. The status is 4 and OUT is empty. `dup.wat` defines `u/main` twice. The status is 9 and OUT is empty.

## Asked

Records, enums, `match`, parameters, and the rest of the operation table are not in this increment.
