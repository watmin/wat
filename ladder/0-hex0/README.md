# hex0

Usage: `hex0 IN OUT` on x86-64 Linux.

The one binary not built from source: the seed, written as commented hex so every byte can be audited by hand. The contract is this rung's: this file and `tests/`. The machine code and the syscalls belong to the target `x86_64-linux`. The source is `ladder/0-hex0/x86_64-linux/hex0.hex0`, and the seed is `ladder/0-hex0/x86_64-linux/hex0`. Verify the binary by decoding that source with `tools/check/hex-check.py` and comparing the bytes, or by running this seed on that source and comparing again.

A ladder is the sequence of programs that builds watc, each one built by the one below it. A rung is one program in that sequence. The design is `docs/excursus/2026/10/001-the-ladder/DESIGN-the-ladder.md`.

The input language is commented hex, read one byte at a time.

- `#` or `;` starts a comment that runs to the next LF or end of input. A CR does not end it.
- Whitespace (exactly space, tab, CR, LF) is skipped.
- A byte's two digits may be split by whitespace or a comment.
- `0-9`, `a-f` and `A-F` are hex digits, two per output byte, high nibble first.

It writes those bytes to OUT. OUT is created or truncated with mode `0755`. Once OUT has been opened and the checks before `fchmod` have passed, its mode is 0755 on every later status. `fchmod` runs before `ftruncate`, so a failed chmod leaves the previous bytes in place. A device or FIFO is refused before `fchmod`.

Status 7 applies only once OUT opened. A read-only same file does not open: the status is 3 and the file is unchanged.

A signal (SIGXFSZ under `ulimit -f`) ends hex0 with no status, and a FIFO or terminal IN can block.

Total means every failure stops with a named status. hex0 does not report done after a failure.

| exit | meaning |
|---|---|
| 0 | done. OUT holds the decoded bytes, mode 0755 |
| 1 | wrong argument count. OUT was not created |
| 2 | IN cannot be opened, or fstat on IN failed. OUT was not created when the open of IN failed. When fstat on IN failed, OUT is not truncated: a new file is empty, and an existing file still holds its old bytes and its old mode |
| 3 | OUT cannot be opened, or is not a regular file, or fchmod failed, or fstat on OUT failed. A read-only same file fails here. OUT was not created when the open failed. Otherwise OUT is not truncated: a new file is empty, and an existing file or device is unchanged, mode included |
| 4 | a byte that is not a digit, a comment, or whitespace (exactly space, tab, CR, LF). OUT was truncated, then holds the bytes decoded before the bad byte, mode 0755 |
| 5 | an odd number of digits at end of input. OUT was truncated, then holds the bytes decoded before the trailing nibble, mode 0755 |
| 6 | a read, write, close or truncate failed. A failed truncate leaves the old bytes, mode already 0755. A failed read or write leaves the bytes written before that failure, after the truncate, mode 0755. A failed close leaves the full decoded bytes, mode 0755 |
| 7 | IN and OUT are the same file, and OUT opened. OUT is untouched |

Registers in the seed: `r12` is IN, `r13` is OUT, `r14b` is the pending-nibble flag, `r15b` is that nibble, `r10b` is set inside a comment, `rbp` holds IN's `st_dev`, `r8` holds IN's `st_ino`. `rcx` is clobbered by `syscall` and is not held. One byte of buffer sits at `[rsp]`, inside the 144-byte stack slot that `fstat` fills. 144 bytes is the x86-64 ABI's `struct stat`. `st_dev` is at offset 0, `st_ino` at offset 8, and `st_mode` at offset 24. `syscall` returns in `rax` and clobbers `rcx` and `r11`; every other register survives.

Every jump target in the source's instruction comments is an offset from the first code byte.
