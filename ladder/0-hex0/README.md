# hex0

Usage: `hex0 IN OUT`.

One per target: that target's seed, written as commented hex so every byte can be audited by hand. The contract is this rung's: this file and `tests/`. The machine code and the syscalls belong to the target `x86_64-linux`. The source is `ladder/0-hex0/x86_64-linux/hex0.hex0`, and the seed is `ladder/0-hex0/x86_64-linux/hex0`. Its sha256 is `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`. From the repository root, a stranger checks the bytes with:

```
sed 's/[#;].*//' ladder/0-hex0/x86_64-linux/hex0.hex0 | xxd -r -p | cmp - ladder/0-hex0/x86_64-linux/hex0
```

That decode shares no code with `tools/check/hex-check.py`, which is a second reader of the same source. Both readers agree byte for byte. The trust is the hand audit, not which reader ran first. Running this seed on that source proves self-consistency, not trust. The disassembly recipe, the registers and the file offsets live in the target header and in `ladder/0-hex0/x86_64-linux/gate.tsv`.

A ladder is the sequence of programs that builds watc, each one built by the one below it. A rung is one program in that sequence. The design is `docs/excursus/2026/10/001-the-ladder/DESIGN-the-ladder.md`.

The input language is commented hex, read one byte at a time.

- `#` or `;` starts a comment that runs to the next LF or end of input. A CR does not end it.
- Whitespace (exactly space, tab, CR, LF) is skipped.
- A byte's two digits may be split by whitespace or a comment.
- `0-9`, `a-f` and `A-F` are hex digits, two per output byte, high nibble first.

It writes those bytes to OUT. OUT is created or truncated with mode `0755`. The mode is 0755 once `fchmod` has succeeded, including on every later status. `fchmod` runs before `ftruncate`, so a failed chmod leaves the previous bytes in place. The order on OUT is: a failed open or fstat is 3, then the same file is 7, then a file that is not regular is 3. A device or FIFO is refused before `fchmod`. A FIFO opened with no reader fails the open. A FIFO opened with a reader fails the regular-file check. Both are status 3, and the mode is unchanged.

`hex0 /dev/null /dev/null` exits 7. Status 7 applies only once OUT opened. A read-only same file is status 3, unless the open succeeds, which needs `CAP_DAC_OVERRIDE` effective over that inode on a writable mount, and then it is 7. `fs.protected_regular` can refuse the open in a sticky world-writable directory. Opening a device can have driver side effects. Unchanged means mode and bytes.

With the default `SIGXFSZ` disposition, a file-size limit kills hex0 (shell status 153). With `SIGXFSZ` ignored, the failed write is status 6 and the bytes written before it are kept. A FIFO or terminal used as IN can block.

Total means every failure stops with a named status, within the bound in the design: a signal or a blocked read is not a status. hex0 does not report done after a failure.

| exit | meaning |
|---|---|
| 0 | done. OUT holds the decoded bytes, mode 0755 |
| 1 | wrong argument count. OUT was not created |
| 2 | IN cannot be opened, or fstat on IN failed. OUT was not created when the open of IN failed. When fstat on IN failed, OUT is not truncated: a new file is empty, and an existing file still holds its old bytes and its old mode |
| 3 | OUT cannot be opened, or is not a regular file, or fchmod failed, or fstat on OUT failed. A read-only same file fails here when the process lacks `CAP_DAC_OVERRIDE`. OUT was not created when the open failed. Otherwise OUT is not truncated: a new file is empty, and an existing file or device is unchanged, mode included |
| 4 | a byte that is not a digit, a comment, or whitespace (exactly space, tab, CR, LF). OUT was truncated, then holds the bytes decoded before the bad byte, mode 0755 |
| 5 | an odd number of digits at end of input. OUT was truncated, then holds the bytes decoded before the trailing nibble, mode 0755 |
| 6 | a read, write, close or truncate failed. A failed truncate leaves the old bytes, mode already 0755. A failed read or write leaves the bytes written before that failure, after the truncate, mode 0755. A failed close leaves the full decoded bytes, mode 0755. An ignored `SIGXFSZ` is this status, and the bytes written before the failed write are kept |
| 7 | IN and OUT are the same file, and OUT opened. OUT is untouched |
