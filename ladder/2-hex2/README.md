# hex2

Usage: `hex2 IN OUT`.

Rung 2 of the ladder. Hex1 builds it. This file is the contract. The fixtures in `tests/` are the contract's inputs. The machine code belongs to `x86_64-linux`. Bash, the top-level `build`, is the sequencer until M0's brief. It runs hex1's two lines, then:

```
out/hex1 ladder/2-hex2/x86_64-linux/hex2.hex1 out/hex2
out/hex2 ladder/2-hex2/x86_64-linux/hex2.hex2 out/hex2-self
```

The gate checks the products. It does not call `build`. Statuses 0–11 are hex1's, with hex1's OUT handling. The words are in `ladder/1-hex1/README.md`.

## The language

Hex2 accepts hex1's language. A label is still one byte, the same bytes hex1 allows. `:` defines it. `%` followed by a label emits the 4-byte relative hex1 emits, signed, from −2147483648 through 2147483647.

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
| 4 | a bad byte, including a digit after `%` other than `1` or `2`, and a byte after `:` or `%` that is not a legal label. OUT holds the bytes emitted before that byte, mode 0755 |
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

`bad-width-0.hex2`, `bad-width-3.hex2`, `bad-width-a.hex2`, and `bad-width-A.hex2` are a digit after `%` with no byte before it. `bad-width-after.hex2` is the byte `41` and then `%3G`. `bad-amp.hex2` is `&3`. `label-amp.hex2` defines the label `&` and takes the 4-byte relative of it.

## Asked

A label longer than one byte is unruled. A name that keeps `:G` followed by a hex digit as label `G` and then that digit cannot also contain `a` through `f`, and no switch that preserves hex1 has passed the four questions.

## The target

`x86_64-linux/hex2.hex1` is the program in hex1's language, with the displacements written out. `x86_64-linux/hex2.hex2` is the same program with labels. A one-byte relative there is `%1`. A four-byte relative is `%`. The low 4 bytes of `e_entry` are `&` of the label on the first instruction. The high 4 bytes stay zero. `x86_64-linux/syscalls.tsv` is hex1's call list. `x86_64-linux/gate.tsv` names `objdump_machine`, `insn_width`, `code_base`, `size`, and `lseek_nth`.
