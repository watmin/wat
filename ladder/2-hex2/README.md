# hex2

Usage: `hex2 IN OUT`.

Rung 2 of the ladder. Hex1 builds it. This file is the contract. The fixtures in `tests/` are the contract's inputs. The machine code belongs to `x86_64-linux`. Bash, the top-level `build`, is the sequencer until M0's brief. It runs hex1's two lines, then:

```
out/hex1 ladder/2-hex2/x86_64-linux/hex2.hex1 out/hex2
out/hex2 ladder/2-hex2/x86_64-linux/hex2.hex2 out/hex2-self
```

The gate checks the products. It does not call `build`. Statuses 0–11 are hex1's, with hex1's OUT handling. The words are in `ladder/1-hex1/README.md`.

## The language

Hex2 accepts hex1's language except one form. `:` defines a name. `%` followed by a name emits the 4-byte relative hex1 emits, signed, from −2147483648 through 2147483647. A name is the bytes after the introducer, and it ends at the next space, tab, CR, or LF. A name may contain digits, including `a` through `f`. A name of one byte at the end of a line is the hex1 label. `:G48` on one line is the name `G48`. `:G` and then `48` on the next line is label `G` and the byte `0x48`. A name is at most 16 bytes. The table holds 64 names. An empty name, a 17th byte, and a 65th name are bad bytes.

`%1` followed by a label emits that same difference as one signed byte, from −128 through 127. `%2` followed by a label emits it as two signed bytes, from −32768 through 32767. The difference is `target − (the offset after the field)`. A digit after `%` other than `1` or `2` is a bad byte, the same OUT handling as any other bad byte.

`&` followed by a label emits the virtual address of that label: the file offset plus `0x400000`, four unsigned bytes, little-endian. `&` is still a legal label name. It is this form only when it is the introducer.

A displacement outside the field just opened is status 10, and so is a virtual address that does not fit in four unsigned bytes. On this rung a relative field is one byte, two bytes, or four. The gate reaches the one-byte ends with the fixtures below. It reaches the two-byte ends by building an input whose output is 32768 bytes or one past that. An output shorter than 2147483648 bytes does not reach the four-byte relative ends. An output shorter than 4290772992 bytes does not reach status 10 for `&`.

## Exit status

| exit | meaning |
|---|---|
| 0 | done. OUT holds the decoded bytes, mode 0755 |
| 1 | wrong argument count. OUT was not created |
| 2 | IN cannot be opened, or fstat on IN failed |
| 3 | OUT cannot be opened, or is not a regular file, or fchmod failed, or fstat on OUT failed |
| 4 | a bad byte, including a digit after `%` other than `1` or `2`, an empty name, a name longer than 16 bytes, and a 65th name. OUT holds the bytes emitted before that byte, mode 0755 |
| 5 | an odd number of digits at end of input |
| 6 | a read, write, close, or truncate failed |
| 7 | IN and OUT are the same file |
| 8 | a reference to a label that was never defined |
| 9 | a label defined twice |
| 10 | a displacement outside the field just opened. Raised at that write, before the field's bytes. OUT holds the bytes already emitted, mode 0755 |
| 11 | IN cannot be rewound, because lseek failed |

fchmod and ftruncate run before either pass. A refusal after that point leaves mode 0755 and the bytes pass 2 has already written.

## Fixtures

`rel1-zero.hex2` is `%1L` then `:L` then the byte `41`. The field is one byte and the displacement is 0. The bytes are `00 41`.

`rel1-max.hex2` is a one-byte forward displacement of 127. `rel1-min.hex2` is a one-byte backward displacement of −128. `rel1-over.hex2` and `rel1-under.hex2` are one past those ends, status 10.

`rel2-zero.hex2` is `%2L` then `:L` then the byte `41`. The bytes are `00 00 41`.

`abs-four.hex2` is `&L` then `:L` then the byte `41`. The label is at offset 4. The bytes are `04 00 40 00 41`. `abs-base.hex2` defines `L` at offset 0 and then takes its address. The bytes are `00 00 40 00`. `abs-undef.hex2` is `&Z` with no definition, status 8.

`name-glued.hex2` is `:G48`, then the byte `41`, then `%G48`. The name is `G48`. The bytes are `41 FB FF FF FF`. `name-split.hex2` is `:G` and then `48` on the next line. The bytes are `48`. `name-word.hex2` is `:main`, then `%1main`, then the byte `41`. The bytes are `FF 41`. `name-twice.hex2` defines `main` twice, status 9. `name-undef.hex2` is `%main`, status 8.

Seven hex1 fixtures are names under this rule, so the parity row does not compare them: `label-colon.hex1`, `label-digit.hex1`, `label-digit-after.hex1`, `label-hash.hex1`, `label-low.hex1`, `label-percent.hex1`, and `label-semi.hex1`. `41:0` is the byte `41` and the name `0`.

`bad-width-0.hex2`, `bad-width-3.hex2`, `bad-width-a.hex2`, and `bad-width-A.hex2` are a digit after `%` with no byte before it. `bad-width-after.hex2` is the byte `41` and then `%3G`. `bad-amp.hex2` is `&` and then a newline, an empty name. `label-amp.hex2` defines the name `&` and takes the 4-byte relative of it.

## The target

`x86_64-linux/hex2.hex1` is the program in hex1's language, with the displacements written out. `x86_64-linux/hex2.hex2` is the same program with labels. A one-byte relative there is `%1`. A four-byte relative is `%`. The low 4 bytes of `e_entry` are `&` of the label on the first instruction. The high 4 bytes stay zero. `x86_64-linux/syscalls.tsv` is hex1's call list. `x86_64-linux/gate.tsv` names `objdump_machine`, `insn_width`, `code_base`, `size`, and `lseek_nth`.
