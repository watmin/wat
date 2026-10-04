# EXPECTATIONS — rung 0: hex0

Written 2026-10-03, before the strike. Every row must be a command in `tools/verify.sh`.

| # | what | the command that checks it | expected |
|---|---|---|---|
| 1 | The seed is its source | `tools/hex-check.py seed/hex0.hex0` → bytes; `cmp` with `seed/hex0` | identical |
| 2 | The seed matches a second decoder | strip comments, then `xxd -r -p`; `cmp` with `seed/hex0` | identical |
| 3 | The fixpoint | `seed/hex0 seed/hex0.hex0 /var/tmp/…/h1`; `cmp h1 seed/hex0` | identical, exit 0 |
| 4 | It builds a program that runs | `seed/hex0 docs/bootstrap/probe-exit42.hex0 out`; run `out` | `out` equals the `xxd` decode; `out` exits 42 |
| 5 | Output is executable | `stat -c %a out` | `755` |
| 6 | Format edges | fixtures: lower and upper case; CRLF line ends; a comment at end of file with no newline; `;` and `#` comments; digits split across whitespace (`4 1` is one byte, `0x41`) | each decodes to its expected bytes |
| 7 | Every refusal, by its own status | fixtures: argc 2; a missing IN; OUT in a missing directory; a `G`; an odd digit count | exits 1, 2, 3, 4, 5, each for the matching fixture and no other |
| 8 | Syscalls are only the honest ones | `strace -f seed/hex0 …` on row 3 | only `execve` (the kernel's), then `open`, `read`, `write`, `close`, `exit` |
| 9 | Every encoded instruction is what its comment says | `objdump -D -b binary -m i386:x86-64` on the code bytes, read beside `hex0.hex0` | every instruction comment matches the disassembly |
| 10 | Small enough to read | `wc -c seed/hex0` | ≤ 512 bytes |
| 11 | Commented throughout | every line of `hex0.hex0` that carries a hex digit also carries a comment (checked by `tools/hex-check.py --lint`) | 0 bare lines |

**Runtime prediction:** 1–3 hours.

**Size prediction:** 250–400 bytes. stage0-posix's AMD64 hex0 is in that range. Ours adds distinct refusals, so
expect the upper half.

**Trap doors:**
- **`p_filesz`/`p_memsz` must equal the real file size.** A stale header loads short, and the failure looks like a
  bad instruction far from the cause.
- **Relative jumps are hand-computed.** Every `rel8`/`rel32` is a distance counted by hand. Row 9's disassembly is
  where an off-by-one shows; the fixpoint alone can still pass with a wrong but self-consistent jump.
- **`O_CREAT` without a mode gives garbage permissions.** Pass `0755` (octal), which is `0x1ED`.
- **End of file inside a comment** must still be clean, with status 0. That is row 6's no-newline fixture.
