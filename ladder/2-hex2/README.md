# hex2

Usage: `hex2 IN OUT`.

Rung 2 of the ladder. Hex1 builds it. This file is the contract. The machine code belongs to `x86_64-linux`. Bash, the top-level `build`, is the sequencer until M0's brief. `build` does not run this rung yet. The gate does not call `build`.

Statuses 0–11 are hex1's, with hex1's OUT handling. The words are in `ladder/1-hex1/README.md`. A refusal that needs a number past 11 is unruled.

## The language

Hex2 accepts hex1's language. Hex1 already has one-byte labels and one relative form: `%` emits 4 little-endian bytes, signed, from −2147483648 through 2147483647.

This rung adds the forms the hex1 crawl left here:

- an 8-bit relative
- a 16-bit relative
- an absolute address
- a label longer than one byte

The spelling of each form is unruled. No fixture is in the tree until a spelling is ruled. No target source is in the tree until the program is written.

## Asked

- Which bytes introduce the 8-bit relative, the 16-bit relative, and the absolute address?
- How a label longer than one byte is written, and how it ends?
- What status an 8-bit or 16-bit displacement takes when it does not fit?
- The build lines. Rung 2 is built by rung 1: `out/hex1` reads this rung's source in hex1's language, and the product reads the same program in hex2's language.

## The target

`x86_64-linux/hex2.hex1` will be the program in hex1's language. `x86_64-linux/hex2.hex2` will be the same program in this rung's language. Neither file is in the tree.
