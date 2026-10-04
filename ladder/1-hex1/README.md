# hex1

Usage: `hex1 IN OUT`.

Rung 1 of the ladder. The seed builds it. This file is the contract. The fixtures in `tests/` are the contract's inputs. The machine code belongs to `x86_64-linux`. Bash, the top-level `build`, is the sequencer until M0's brief. It runs:

```
ladder/0-hex0/x86_64-linux/hex0 ladder/1-hex1/x86_64-linux/hex1.hex0 out/hex1
out/hex1 ladder/1-hex1/x86_64-linux/hex1.hex1 out/hex1-self
```

The gate checks the two products. It does not call `build`. Statuses 0–7 are hex0's, with hex0's OUT handling: open flags `0x841`, no truncate flag, mode `0x1ED`, the same file is 7, a file that is not regular is 3 before fchmod, and fchmod runs before ftruncate. The words for 0–7 are in `ladder/0-hex0/README.md`.

## The language

Hex1 accepts hex0's language, and two forms.

- `#` or `;` starts a comment that runs to the next LF or end of input. A CR does not end it.
- Whitespace, exactly space, tab, CR, and LF, is skipped.
- A byte's two digits may be split by whitespace or a comment.
- `0-9`, `a-f`, and `A-F` are hex digits, two per output byte, high nibble first.
- `:c` defines label `c` at the current output offset. The offset counts from 0 at the file's first byte. The definition emits nothing.
- `%c` emits `target − (the offset after these 4 bytes)` as 4 bytes, little-endian, signed. The accepted values run from −2147483648 through 2147483647. A value outside that range is status 10. The output offset advances by 1 for a hex pair and by 4 for a reference, so an output shorter than 2147483648 bytes reaches neither end of that range and does not reach status 10. No fixture of that size is in `tests/`.

A label is one byte: printable ASCII, and not a hex digit, not whitespace, and not `#` `;` `:` `%`. Printable ASCII here is the bytes from `0x21` through `0x7E`. A byte after `:` or `%` that is not a legal label is status 4, the same OUT handling as any other bad byte.

There is no 8-bit relative form.

Pass 1 records labels. `lseek(IN, 0, SEEK_SET)` rewinds the input. Pass 2 emits bytes and displacements. `%` advances the offset by 4. `:` records the current offset and emits nothing. A hex pair advances the offset by 1.

## Exit status

| exit | meaning |
|---|---|
| 0 | done. OUT holds the decoded bytes, mode 0755 |
| 1 | wrong argument count. OUT was not created |
| 2 | IN cannot be opened, or fstat on IN failed. OUT was not created when the open of IN failed. When fstat on IN failed, OUT is not truncated |
| 3 | OUT cannot be opened, or is not a regular file, or fchmod failed, or fstat on OUT failed. OUT was not created when the open failed. Otherwise OUT is not truncated |
| 4 | a byte that is not a digit, a comment, whitespace, or a legal label byte after `:` or `%`. OUT was truncated, then holds the bytes decoded before the bad byte, mode 0755 |
| 5 | an odd number of digits at end of input. OUT was truncated, then holds the bytes decoded before the trailing nibble, mode 0755 |
| 6 | a read, write, close, or truncate failed |
| 7 | IN and OUT are the same file, and OUT opened. OUT is untouched |
| 8 | a reference to a label that was never defined. Raised in pass 2 at that reference, before its 4 bytes are written. OUT holds the bytes pass 2 already emitted, mode 0755 |
| 9 | a label defined twice. Raised in pass 1. OUT is empty, mode 0755 |
| 10 | a displacement outside −2147483648 through 2147483647. Raised at the same write as status 8, before those 4 bytes. The gate does not run this status |
| 11 | IN cannot be rewound, because lseek failed. Raised after pass 1, before pass 2. OUT is empty, mode 0755 |

fchmod and ftruncate run before either pass. A refusal after that point leaves mode 0755 and the bytes pass 2 has already written. The gate runs statuses 8, 9, and 11 with OUT absent and with OUT already present, and judges the status, the bytes, and the mode.

## Fixtures

`forward.hex1` is `%L` then `:L` then the byte `41`. The label is at offset 4. The displacement is 0. The bytes are `00 00 00 00 41`.

`backward.hex1` is `:L` then the byte `41` then `%L`. The label is at offset 0. The field ends at offset 5. The displacement is −5. The bytes are `41 fb ff ff ff`.

`next.hex1` is `%N` then `:N`. The displacement is 0. The bytes are `00 00 00 00`.

`label-digit.hex1`, `label-hash.hex1`, `label-semi.hex1`, `label-colon.hex1`, `label-percent.hex1`, `label-space.hex1`, `label-lf.hex1`, `label-low.hex1`, and `label-percent-digit.hex1` are status 4 with no byte before the bad label. `label-digit-after.hex1` is `41` and then a digit label, status 4, and OUT holds that one byte.

`undef.hex1` is `%Z`, status 8, and OUT is empty. `undef-after.hex1` is the byte `41` and then `%Z`, status 8, and OUT holds that one byte. `twice.hex1` is status 9, and OUT is empty. Status 11's input is a FIFO: the writer feeds `41` and a newline, then closes. Pass 1 reads that byte, the rewind fails, and pass 2 writes nothing, so OUT is empty. Each of these leaves mode 0755.

## The target

`x86_64-linux/hex1.hex0` is the program in hex0's language. `x86_64-linux/hex1.hex1` is the same program with labels. `x86_64-linux/syscalls.tsv` is the call list: hex0's calls, plus `lseek` 8.

`x86_64-linux/gate.tsv` names `objdump_machine`, `insn_width`, `code_base`, `size`, and `lseek_nth`. The disassembly row reads the first four. The size row reads `size` and compares it to the file length and to `p_filesz` and `p_memsz`. The lseek fault row reads `lseek_nth`.
