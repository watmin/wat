# EXPECTATIONS — rung 0: hex0

Written 2026-10-03, before the strike. Every row must be a command in `tools/verify.sh`.

| # | what | the command that checks it | expected |
|---|---|---|---|
| 1 | The seed is its source | `tools/check/hex-check.py ladder/0-hex0/hex0.hex0` → bytes; `cmp` with `ladder/0-hex0/hex0` | identical |
| 2 | The seed matches a second decoder | strip comments, then `xxd -r -p`; `cmp` with `ladder/0-hex0/hex0` | identical |
| 3 | The fixpoint | `ladder/0-hex0/hex0 ladder/0-hex0/hex0.hex0 out/h1`; `cmp out/h1 ladder/0-hex0/hex0` | identical, exit 0 |
| 4 | It builds a program that runs | `ladder/0-hex0/hex0 ladder/0-hex0/tests/exit42.hex0 out/exit42`; run it | it equals the `xxd` decode, and exits 42 |
| 5 | Output is executable | `stat -c %a out/exit42`, and the same for an OUT that already exists at mode `600` | `755` |
| 6 | Format edges | fixtures: lowercase and upper case hex digits; CRLF line ends; a comment at end of file with no newline; `;` and `#` comments; digits split across whitespace (`4 1` is one byte, `0x41`); a comment between a byte's two digits | each decodes to its expected bytes |
| 7 | Every refusal, by its own status | fixtures: argc 2; a missing IN; OUT in a missing directory; a `G`; an odd digit count; a reject byte after a pending nibble (`0x2F`, `0x40`, `0x80`, `0xFF`); the same path; a hard link; a symlink | exits 1, 2, 3, 4, 5, 4, 7, 7, 7, each for the matching fixture and no other. The reject fixtures leave the bytes decoded before the pending nibble. The three same-file cases leave IN byte-identical |
| 8 | Syscalls are only the honest ones | `strace -f ladder/0-hex0/hex0 …` on row 3 | only `execve` (the kernel's), then `open`, `fstat`, `fchmod`, `ftruncate`, `read`, `write`, `close`, `exit` |
| 9 | Every encoded instruction is what its comment says | `objdump -D -b binary -m i386:x86-64` on the code bytes, compared mechanically against each line's instruction comment by `tools/verify.sh` | every instruction comment matches the disassembly |
| 10 | Small enough to read | `wc -c ladder/0-hex0/hex0`, and `p_filesz` and `p_memsz` equal that length | 537 bytes. 514 moved because OUT is refused, before `fchmod`, when it is not a regular file |
| 0 | The layout | `tools/layout.sh`, every rule of `docs/LAYOUT.md`, plus at least one mutant per rule, including: a stray top-level file, a second ELF, a brief inside a rung, a gap in rung numbers, a rung README without an exit table, an edit under `archived/`, a `tools/` script writing into `out/`, a tracked `.wat` file containing `:wat::core::+`, rule 9's docs-shape and bare-reference mutants, a non-image file in `brand/` | `layout: ok` on the tree; each mutant red, naming its rule, then reverted |
| 11 | Commented throughout | every line of `hex0.hex0` that carries a hex digit also carries a comment (checked by `tools/check/hex-check.py --lint`) | 0 bare lines |
| 12 | The fuzz discriminates | `tools/check/fuzz-hex0.py` runs 2,000 cases from a fixed seed against a reference that states whether OUT exists, comparing bytes on every status. It then repeats the slice on a seed whose a-f bound is flipped, and on a seed whose letter offset is flipped | 2,000 agreements; the status mutant disagrees; the letter-offset mutant disagrees on the decoded bytes; neither mutant is kept |
| 13 | Fault paths | `tools/check/fault.c` built with `gcc` into `out/fault`. Each of `fstat` on IN, `fstat` on OUT, `fchmod`, `read`, `write`, `close` and `ftruncate` is forced to fail, then the same input is run with the fault removed | the forced call exits 2, 3, 3, 6, 6, 6, 6 respectively, and each control exits 0 with the decoded byte |

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
