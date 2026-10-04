# BRIEF — rung 0: hex0, the seed

> wat takes material form this day. This is the first rung of the ladder (`DESIGN-the-ladder.md`): the one binary not built
> from source, small enough that a person can audit every byte against the instruction it encodes.

## YOU ARE NEW TO THIS REPOSITORY — read first

1. `docs/LAYOUT.md` first (where everything lives, enforced). Then `README.md`, then `docs/excursus/2026/10/001-the-ladder/DESIGN-the-ladder.md`: what is given (the Linux kernel, through syscalls), what is
   not (no libc, no loader, no borrowed assembler), and the four rules every rung follows.
2. `ladder/0-hex0/tests/exit42.hex0`. It is the input format, and a complete 132-byte static ELF you can copy the
   headers from. It was decoded by Python and by `xxd` to the same bytes, and it ran with exit code 42.
3. `docs/MACHINE.md`: the tools on this machine. All of them CHECK. None of them builds a rung, except the seed decode named in `docs/LAYOUT.md` rule 4.
4. Reference material from watc, read-only: watmin/the-little-wat at `/home/watmin/Work/holon/the-little-wat`.
   - `elf/hello.wat` is a hand-built 166-byte ELF.
   - `elf/lib/x86.wat` holds instruction encodings.
   - The syscall numbers are in `elf/lib/runtime.wat:2845`: read 0, write 1, open 2, close 3, exit 60.

   That repository stays as it is; this strike only reads it.

## THE WORK

**hex0**: a static x86-64 Linux ELF, written as commented hex in `ladder/0-hex0/x86_64-linux/hex0.hex0`. The contract is the rung's (`README.md` and `tests/`). The machine code and the syscalls belong to the target `x86_64-linux`. The paths below follow `docs/LAYOUT.md` (reading item 1).
- **Its contract.**
  - **Invocation.** It runs as `hex0 IN OUT`.
  - **Input.** It reads IN byte by byte.
    - `#` or `;` starts a comment that runs to the next LF or end of input. A CR does not end it.
    - Whitespace (exactly space, tab, CR, LF) is skipped.
    - A byte's two digits may be split by whitespace or a comment.
    - `0-9`, `a-f` and `A-F` are hex digits, two per output byte, high nibble first.
  - **Output.** It writes each byte to OUT, created or truncated with mode `0755`, so the output runs directly. The mode is 0755 once `fchmod` has succeeded. With the default `SIGXFSZ` disposition a file-size limit kills hex0. With `SIGXFSZ` ignored, the failed write is status 6 and the bytes written are kept. A FIFO OUT is status 3. A FIFO or terminal IN can block. The stat buffer is 144 bytes because that is the x86-64 ABI's `struct stat`.
- **Refusals.** Total means every failure stops with a named status. hex0 does not report done after a failure. Each status says what OUT holds. The same table is in the source header and the rung README.

  | exit | meaning | OUT |
  |---|---|---|
  | 0 | done | the decoded bytes, mode 0755 |
  | 1 | wrong argument count | not created |
  | 2 | IN cannot be opened, or fstat on IN failed | not created when the open of IN failed. When fstat on IN failed: not truncated, so a new file is empty and an existing file still holds its old bytes |
  | 3 | OUT cannot be opened, or is not a regular file, or fchmod failed, or fstat on OUT failed. A read-only same file fails here | not created when the open failed. When fstat on OUT failed, fchmod failed, or OUT is not a regular file: not truncated, so a new file is empty and an existing file or device is unchanged, mode included |
  | 4 | a byte that is not a digit, a comment, or whitespace (exactly space, tab, CR, LF) | truncated, then the bytes decoded before the bad byte, mode 0755 |
  | 5 | an odd number of digits at end of input | truncated, then the bytes decoded before the trailing nibble, mode 0755 |
  | 6 | a read, write, close or truncate failed | a failed truncate leaves the old bytes, mode already 0755. A failed read or write leaves the bytes written before that failure, after the truncate, mode 0755. A failed close leaves the full decoded bytes, mode 0755 |
  | 7 | IN and OUT are the same file, and OUT opened | untouched |

- **The seed.** The one binary not built from source: the seed, written as commented hex so every byte can be audited by hand. `ladder/0-hex0/x86_64-linux/hex0` is that ELF, produced ONCE by decoding `ladder/0-hex0/x86_64-linux/hex0.hex0` with an
  independent decoder: a Python script you write at `tools/check/hex-check.py`. That one decode is the declared exception to "tools never build" (`docs/LAYOUT.md` rule 4); afterwards the script only checks. hex0 then has to
  reproduce `ladder/0-hex0/x86_64-linux/hex0` from its own source.
- **The rung's README.** `ladder/0-hex0/README.md` states the contract and the exit-status table (`docs/LAYOUT.md`,
  rule 5).
- **The harness.** `tools/verify.sh` runs `tools/layout.sh` first: every rule of `docs/LAYOUT.md`, each a check
  that fails loudly. It then runs every row of `EXPECTATIONS-hex0.md`. The fault injector is built in the sandbox, not
  in `out/`. The gate exits nonzero on any failure.

## SKETCH — the shape, in prose

- **Startup.** `[rsp]` is argc and argv sits after it. Check argc == 3. Open argv[1] read-only (status 2 on failure).
  Open argv[2] with `O_WRONLY|O_CREAT|O_NONBLOCK` and mode `0755`, without `O_TRUNC` (status 3). `fstat` both descriptors.
  The same device and inode, once OUT has opened, is status 7, and the file is left untouched. A read-only same file is status 3 without `CAP_DAC_OVERRIDE`. If OUT is not a regular file, status 3, before `fchmod`. Otherwise `fchmod` OUT to `0755`
  (status 3 on failure) and `ftruncate` it to 0 (status 6 on failure).
- **The loop.** Read one byte into a stack slot. At end of file:
  - a pending high nibble means status 5;
  - otherwise close OUT. A negative close is status 6. Success exits 0.

  Otherwise:
  - `#` or `;`: skip bytes until the next LF or end of input. A CR does not end a comment.
  - Whitespace (exactly space, tab, CR, LF): skip it.
  - A digit: convert it. If no nibble is pending, keep it as the high nibble. If one is, combine the two and write
    one byte (status 6 on a short write, a failed close, or a failed truncate).
  - Anything else: status 4.
- **Commenting.** Every line of `ladder/0-hex0/x86_64-linux/hex0.hex0` that carries bytes ends with a comment naming the instruction or field
  those bytes encode, as `ladder/0-hex0/tests/exit42.hex0` does. The header comment carries the exit-status table and the register
  conventions.

Registers and layout are yours to choose. Small and readable beat clever: one byte at a time is fast enough.

## BLAST RADIUS

This repository only, in `docs/LAYOUT.md`'s places:
- `ladder/0-hex0/`: `README.md`, `tests/`, and `x86_64-linux/` (`hex0.hex0`, `hex0`);
- `tools/verify.sh`, `tools/layout.sh`, `tools/check/hex-check.py`, `tools/check/fuzz-hex0.py` and `tools/check/fault.c`;
- `docs/excursus/2026/10/001-the-ladder/SCORE-hex0.md`.

Nothing goes anywhere else.

## STOP TRIGGERS

- **STOP-1** — the format wants something beyond digits, comments and whitespace, such as labels or addresses. That
  belongs to a later rung (hex1, then hex2). Say what, and why.
- **STOP-2** — `hex0` built from its own source differs from `ladder/0-hex0/x86_64-linux/hex0` and the cause cannot be named.
- **STOP-3** — any rung output would have to come from a tool other than a rung (an assembler, `xxd -r`, Python).
  Those check; they never build.

## METHOD

- **Commits.** The tree stays dirty; commit nothing. The orchestrator weighs, then commits.
- **Running and checking.**
  - `timeout -s KILL` on every run.
  - Never read an exit code through a pipe.
  - Never re-run a red.
  - Assert every text replacement.
- **Where you work.** No git in the holon root, and no worktrees. Long-lived sandboxes go under `/var/tmp`.
- **Checks.** Cross-check the hand-encoded instructions with `nasm` or `objdump -D -b binary -m i386:x86-64`, and the
  syscalls with `strace`.
- **Finishing.** Write `docs/excursus/2026/10/001-the-ladder/SCORE-hex0.md` AS YOU GO, then `pulsare_yield kind=scored`.
