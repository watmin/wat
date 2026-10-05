# wat0

Usage: `wat0 IN OUT`.

Rung 4 of the ladder. M0 builds its hex2 text and hex2 emits the binary. This file is the contract. The fixtures in `tests/` are part of it. The machine code belongs to `x86_64-linux`. Bash, the top-level `build`, is the sequencer. It runs M0's lines, then:

```
out/m0 ladder/4-wat0/x86_64-linux/wat0.m0 out/wat0.hex2
out/hex2 out/wat0.hex2 out/wat0
out/hex2 ladder/4-wat0/x86_64-linux/wat0.hex2 out/wat0-self
```

`out/wat0.hex2` is hex2 text. The gate checks the products. It does not call `build`.

wat0 invokes `user/main`. That definition is the rendezvous:

```clojure
(wat.core/defn user/main [] :- wat.type/nil
  ...)
```

A program defines it. wat calls it. The result is nil, so the line a person sees comes from `wat.kernel/println`. The heap is an arena that never frees. A `wat.core/let` binding is visible to the bindings after it, and the arena does not give that storage back.

This increment reads these forms: `wat.core/defn`, the signature `[] :- wat.type/nil`, one body expression, integer literals, names, `wat.core/let`, `wat.core/+`, and `wat.kernel/println` of an integer. A `;` comment runs to the next newline.

The built-ins are the table after the code in `wat0.hex2`. A row is the length, the name's bytes, a class, and the address of its code. Class 1 is an expression. Class 2 is a top-level form. A new built-in is a row plus the code it names.

A defined name may use any namespace except `wat` and `wat.*`. `user/main` is the rendezvous. Any other `user/*` name is definable. wat may later claim another `user/*` name for a rendezvous, so a program should leave those names alone. A definition in `wat` or `wat.*` is a bad form.

## Exit status

| exit | meaning |
|---|---|
| 0 | done. OUT holds what `wat.kernel/println` wrote, mode 0755 |
| 1 | wrong argument count. OUT was not created |
| 2 | IN cannot be opened, or fstat on IN failed |
| 3 | OUT cannot be opened, or is not a regular file, or fchmod failed, or fstat on OUT failed |
| 4 | a bad form, a missing `user/main`, a definition in `wat` or `wat.*`, or a name that is not bound. OUT holds the text already written, mode 0755 |
| 6 | a read, write, close, or truncate failed, or the arena is full |
| 7 | IN and OUT are the same file |
| 9 | `user/main` defined twice. OUT holds the text already written, mode 0755 |

## Fixtures

`forty-two.wat` binds `x` to 40, adds 2, and prints it. The text is `42` and a newline. `seven.wat` prints 7. `helper.wat` defines `user/helper` and `user/main`; only `user/main` runs, and the text is `42` and a newline. `bad.wat` has no body. The status is 4 and OUT is empty. `watns.wat` defines `wat.core/nope`. The status is 4 and OUT is empty. `dup.wat` defines `user/main` twice. The status is 9 and OUT is empty.

## Asked

Records, enums, `match`, parameters, and the rest of the operation table are not in this increment.
