# BRIEF — rung 0: hex0, the seed

> wat takes material form this day. This is the first rung of the ladder (`DESIGN-the-ladder.md`): the one binary taken
> on faith, small enough that a person can audit every byte against the instruction it encodes.

## YOU ARE NEW TO THIS REPOSITORY — read first

1. `README.md`, then `docs/bootstrap/DESIGN-the-ladder.md`: what is given (the Linux kernel, through syscalls), what is
   not (no libc, no loader, no borrowed assembler), and the four rules every rung follows.
2. `docs/bootstrap/probe-exit42.hex0`. It is the input format, and a complete 132-byte static ELF you can copy the
   headers from. It was decoded by Python and by `xxd` to the same bytes, and it ran with exit code 42.
3. `docs/MACHINE.md`: the tools on this machine. All of them CHECK; none of them BUILD.
4. Reference material from watc, read-only: watmin/the-little-wat at `/home/watmin/Work/holon/the-little-wat`.
   - `elf/hello.wat` is a hand-built 166-byte ELF.
   - `elf/lib/x86.wat` holds instruction encodings.
   - The syscall numbers are in `elf/lib/runtime.wat:2845`: read 0, write 1, open 2, close 3, exit 60.

   That repository stays as it is; this strike only reads it.

## THE WORK

**hex0**: a static x86-64 Linux ELF, written as commented hex in `seed/hex0.hex0`.
- **Its contract.**
  - **Invocation.** It runs as `hex0 IN OUT`.
  - **Input.** It reads IN byte by byte.
    - `#` or `;` starts a comment that runs to the end of the line.
    - Space, tab, CR and LF are skipped.
    - `0-9`, `a-f` and `A-F` are hex digits, two per output byte, high nibble first.
  - **Output.** It writes each byte to OUT, created or truncated with mode `0755`, so the output runs directly.
- **Refusals.** Every refusal is total and has its own exit status, documented in the source's header comment:

  | exit | meaning |
  |---|---|
  | 0 | done |
  | 1 | wrong argument count |
  | 2 | IN cannot be opened |
  | 3 | OUT cannot be opened |
  | 4 | a byte that is not a digit, a comment, or whitespace |
  | 5 | an odd number of digits at end of input |
  | 6 | a read or write failed |

- **The seed.** `seed/hex0` is that ELF, produced ONCE by decoding `seed/hex0.hex0` with an independent decoder: a
  Python script you write at `tools/hex-check.py`, which CHECKS only. hex0 then has to reproduce `seed/hex0` from its
  own source.
- **The harness.** `tools/verify.sh` runs every row of `EXPECTATIONS-hex0.md` and exits nonzero on any failure.

## SKETCH — the shape, in prose

- **Startup.** `[rsp]` is argc and argv sits after it. Check argc == 3. Open argv[1] read-only (status 2 on failure).
  Open argv[2] with `O_WRONLY|O_CREAT|O_TRUNC` and mode `0755` (status 3).
- **The loop.** Read one byte into a stack slot. At end of file:
  - a pending high nibble means status 5;
  - otherwise close OUT and exit 0.

  Otherwise:
  - `#` or `;`: skip bytes until LF, or until end of file.
  - Whitespace: skip it.
  - A digit: convert it. If no nibble is pending, keep it as the high nibble. If one is, combine the two and write
    one byte (status 6 on a short write).
  - Anything else: status 4.
- **Commenting.** Every line of `hex0.hex0` that carries bytes ends with a comment naming the instruction or field
  those bytes encode, as `probe-exit42.hex0` does. The header comment carries the exit-status table and the register
  conventions.

Registers and layout are yours to choose. Small and readable beat clever: one byte at a time is fast enough.

## BLAST RADIUS

This repository only:
- `seed/hex0.hex0` and `seed/hex0`;
- `tools/hex-check.py` and `tools/verify.sh`;
- `tests/hex0/` (fixtures);
- `docs/bootstrap/SCORE-hex0.md`.

## STOP TRIGGERS

- **STOP-1** — the format wants something beyond digits, comments and whitespace, such as labels or addresses. That
  belongs to rung 1 (hex1/hex2). Say what, and why.
- **STOP-2** — `hex0` built from its own source differs from `seed/hex0` and the cause cannot be named.
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
- **Finishing.** Write `docs/bootstrap/SCORE-hex0.md` AS YOU GO, then `pulsare_yield kind=scored`.
