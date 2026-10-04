# WEIGH — rung 0: hex0

## Round 1 (2026-10-04)

**My own runs, independent of the harness:**
- `tools/verify.sh`: `verify: ok`, rc 0, with the tree unchanged afterwards.
- My `xxd -r -p` decode of `hex0.hex0` is identical to `ladder/0-hex0/hex0`.
- The seed rebuilding itself is identical, and so is a second generation (the rebuilt hex0 rebuilding itself).
- `readelf`: entry `0x400078`, one `LOAD` segment, R+X, `filesz` = `memsz` = `0x1C7` (455).
- My own `objdump` of the 335 code bytes, diffed line by line against the instruction comments: 119 of 119 match.

**Read, all 455 bytes:**
- **argc.** It is checked against 3.
- **The opens.** `argv[1]` and `argv[2]` are read at `rsp+16` and `rsp+24`. OUT is opened with flags `0x241` and mode
  `0x1ED`.
- **The classifier is total.** It handles comments and whitespace, decodes `0-9`, `A-F` and `a-f`, and every byte in
  the gaps (`:`–`@`, `G`–`` ` ``, and above `f`) exits 4.
- **Nibbles** pair high-first in `r15b`, and a short write exits 6.
- **End of input** inside a comment ends cleanly. A pending nibble at end of input exits 5.

The `nasm` cross-assembly matching byte for byte is credited as a check: nasm built nothing the ladder uses.

**Two things fail Honest. Fix both before the seed lands.** The seed is the root of trust; a second version of it
later costs a second audit.

- **R1 — `close`'s result is ignored.** At `0x137` the seed closes OUT, discards `eax`, and exits 0. On a filesystem
  that reports write-back failure at close, hex0 prints "done" over an incomplete output. Test the result: negative
  exits 6. Widen status 6 to "a read, write or close failed", in the source header, in the README, and in the brief's
  table. Re-run every row. The seed grows by a few bytes, and row 9's count changes accordingly.
- **R2 — layout rule 5 checks a fixed set, 0–6.** `tools/layout.sh` requires the rows `| 0 |` through `| 6 |` in
  every rung's README. Those are hex0's statuses, not the rule. A rung with statuses 0–3 would fail falsely, and a
  rung with a status 7 would pass undocumented. The rule is that the README states the rung's statuses. Make it so:
  - each rung's source header carries one `Exit status:` block, as `hex0.hex0` does;
  - the gate extracts the status numbers from that block and from the README's table, and requires the two sets to
    be equal.

  Add two mutants: a README row missing, and a README row the source does not declare.

**Not findings, recorded:**
- **Size.** It is 455 bytes against a predicted 250–400, under the 512 gate. Distinct refusals and a few rel32 jumps
  cost it. The prediction was mine.
- **IN is never closed.** Exit releases it, and nothing is lost on the read side.
- **A read interrupted by a signal returns `-EINTR` and exits 6.** Nothing sends hex0 signals, and the refusal is
  honest, not silent.

## Round 1, continued — the differential fuzz and the environment (2026-10-04)

The builder: *"let's scrutinize the shit out of this - this must be an exemplar at all times"*.

**The fuzz** (`/var/tmp/hex0-fuzz/fuzz.py`, on the round-1 seed, sha256 `5fbc54f4…f52d51a`) generated 20,000 inputs:
any bytes at all, near-miss bytes (`:` `@` `G` `` ` `` `g` `x` `/` `0x00` `0x7F` `0x80` `0xFF`), comments, CRLF, and
lengths 0 to 4,096. Each ran through hex0 and through a reference decoder written from this brief's contract alone,
not from `hex-check.py`. **0 disagreements** in exit status, or in output bytes on success.

**The environment:**

| case | result |
|---|---|
| argc 1 / 2 / 4 | 1 / 1 / 1 |
| IN mode 000 | 2 |
| OUT is a directory | 3 |
| OUT is `/dev/full` | 6 |
| empty IN | 0, empty OUT |
| existing longer OUT | truncated |
| 4,000,000 digits | 2,000,000 bytes in 7.3 s: one syscall per byte, fine for rung sources of kilobytes |

Two more things fail Honest. Both go into round 2:

- **R3 — an existing OUT keeps its old mode.** `open`'s mode applies only when the file is CREATED. `hex0 ok.hex0 o5`
  with `o5` already at mode `600` exits 0 and leaves it at `600`. The contract's "created or truncated with mode 0755,
  so it runs directly" is false for an existing OUT. Make it true: `fchmod(OUT, 0755)` (syscall 91) after the open,
  with failure exiting 3. Row 5 gains a case where OUT pre-exists at mode `600`. Row 8's syscall list gains `fchmod`.
- **R4 — `hex0 X X` destroys X and exits 0.** Opening OUT truncates the shared file. hex0 then reads an empty IN and
  reports done. A "done" over destroyed source is the worst kind of silent. Refuse it with a new status, **7, "IN and
  OUT are the same file"**:
  - `fstat` both descriptors (syscall 5) and compare `st_dev` and `st_ino`;
  - open OUT WITHOUT `O_TRUNC`, compare, then truncate with `ftruncate(OUT, 0)` (syscall 77), so that the check
    happens before anything is destroyed.

  This catches hard links and symlinks too. Add fixtures: the same path; a hard link; a symlink. Each exits 7, and IN
  is byte-identical afterwards.
- **R1's status 6 wording** then reads "a read, write, close or truncate failed". Every new syscall's failure maps to a
  status, documented in the source header, the README and the brief's table. The R2 gate checks that they agree.

The seed grows: R1 by a few bytes, R3 and R4 by a few dozen. Keep it under 512, and re-audit every jump displacement:
row 9's disassembly is where a hand-counted offset shows itself.

- **R5 — the fuzz is an instrument, so it lives in the repository.** A check that only ran once in `/var/tmp` does
  not guard the next edit of the seed. Add `tools/check/fuzz-hex0.py`: a reference decoder written from the CONTRACT
  (not `hex-check.py`'s code), a generator covering all bytes, near-misses, comments, CRLF and lengths 0–4,096, and a
  fixed seed. `tools/verify.sh` runs a fast slice (2,000 cases) as a row. Each disagreement is kept as a fixture and
  printed. Prove the instrument discriminates with a mutant seed: one byte flipped in the classifier, for example
  `cmp $0x46` → `cmp $0x47`, must produce disagreements. Then revert it.

## Round 2, received (2026-10-04) — R1 and R2 in; R3, R4, R5 still open

`SCORE-hex0.md`'s "Weigh round 1" section shows R1 (`close` checked; status 6 reworded in the source header, the
README and the brief) and R2 (rule 5 derives each rung's statuses from its own `Exit status:` block, with two new
mutants). The seed is 475 bytes; `verify: ok`.

**R3, R4 and R5 were added to this document AFTER the first round-2 knock, and they are not in the tree yet.** They are
"Round 1, continued", above, and they are the rest of round 2: `fchmod` on OUT; status 7 for IN == OUT, with
`fstat` before truncating; and the fuzz as a tracked instrument with a discriminating mutant. Round 2 is scored once
they are in. Then the orchestrator re-runs every row and the fuzz, and casts the wards (`docs/WARDS.md`) on the
finished seed.

## Round 2 complete; the docs reorganized (2026-10-04)

**My runs on the 511-byte seed** (sha256 `190c7129…b24785f8`):
- `tools/verify.sh`: ok.
- My decode is identical to the seed, and two generations are identical.
- My fuzz, generator seed 2, 20,000 cases: 0 disagreements.
- The environment:

  | case | exit |
  |---|---|
  | existing OUT at `600` | 0, and it becomes `755` with the right bytes |
  | same path, hard link, symlink | 7, IN untouched |
  | IN = OUT = `/dev/null` | 7 |
  | OUT = `/dev/null` or `/dev/full` | 3 |

  The last row is `fchmod` refusing a device. Status 3's wording names `fchmod`, so the refusal is honest.

**The builder moved the docs layout to excursus directories** (*"docs/<category>/YYYY/MM/NNN-<slug>... we use excursus
instead of arc"*). This excursus is now `docs/excursus/2026/10/001-the-ladder/`. The exit-42 probe is a test input, so
it moved to `ladder/0-hex0/tests/exit42.hex0`, and `tools/verify.sh`'s three paths moved with it. Verify is green
after the move.

- **R6 — gate the docs shape.** `docs/LAYOUT.md` now has rule 9: `docs/` holds standing `*.md` files and
  `excursus/YYYY/MM/NNN-<slug>/` only; the counter is per month, from `001`, with no gaps; an excursus holds documents
  only. Implement it in `tools/layout.sh`, with mutants for each of these: a stray directory under `docs/`; a counter
  gap (`003` with `002` absent); a `.hex0` inside an excursus; a badly formed slug. Each must go red naming rule 9.

When R6 is in, the orchestrator casts the wards (`docs/WARDS.md`) on the seed, its README and header, and the gate,
and then the rung lands.

- **R6, extended.** Rule 9 also forbids a bare numbered reference to an excursus. Outside `archived/`, a tracked file
  containing `excursus` or `arc` followed by a bare number (`excursus 001`, `arc 12`) is a red. A reference names
  `YYYY/MM/NNN-<slug>`. Add one mutant: a line reading "see excursus 001".
