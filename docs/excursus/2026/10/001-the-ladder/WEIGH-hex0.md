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
  containing `excursus` or `arc` followed by a bare number (the name, a space, then digits) is a red. A reference names
  `YYYY/MM/NNN-<slug>`. Add one mutant: a tracked line with the name, a space, and a counter.

## R6 received (2026-10-04) — the docs shape is gated; the bare-reference half is still open

`SCORE-hex0.md` "R6 — the docs shape" adds four rule-9 mutants (a stray directory, a counter gap, a non-document in an
excursus, a bad slug), and `verify: ok`. **The "R6, extended" item above crossed that score in flight and is not in
`tools/layout.sh`**: no check forbids a bare numbered reference. Add it, with its mutant (the name, a space, and a counter, in a
tracked file outside `archived/`, which must be red naming rule 9).

## The wards, cast on the 511-byte seed (2026-10-04)

Cast per `docs/WARDS.md`, one fresh agent per ward, each reading the target cold. **Disclosure:** these first casts
embedded a CONDENSED text of each ward, not the full signed text the grimoire requires. Their findings stand as
findings. The cast that calls this rung done (`vigilia`) carries every ward's complete text.

### conferre: the contract holds on every behaviour it drove; 3 Level-2 findings

It decoded the seed, reproduced the fixpoint, ran every exit path it could trigger, checked `strace` order and umask
`077`, and drove a nibble split across a comment. Its findings:
- **D1:** `sub $0x7f,%rsp` reserves 127 bytes (`hex0.hex0:87`). `fstat` writes a 144-byte `struct stat` there
  (`:88`), so the write runs 17 bytes past the slot, over argc, argv[0] and argv[1]'s low byte (gdb at `0x4000d1`). The
  header calls it "the 127-byte stack slot".
- **D2:** the branch targets in comments are offsets from the first code byte, and nothing says so. Every one
  disagrees with the brief's own `objdump` command.
- **D3:** "every refusal is total" (`BRIEF-hex0.md:30`) can be read two ways. Refusals 4, 5 and 6, and an `fstat`
  failure on IN, leave a partial or empty OUT behind, and no document says so.

**Weighed:** D1 confirmed by my own reading of `hex0.hex0:87–88`. D2 and D3 accepted as stated.

### nesciens: converges, K = 0; 8 soft stumbles

The same overrun (H4). Branch targets have an undeclared coordinate system, and there are no per-line offsets, no
block labels, and no named exit convention (H8). `p_filesz`'s 511 is not stated as a checkable sum (H7). The README
lacks the usage line and the platform, never defines "ladder", "rung" or "seed", and never says a byte's two digits may
be split by whitespace or a comment (R1–R3, R5, R2). Unstated: why `fchmod` comes before `ftruncate` (H2), the
`st_dev` and `st_ino` offsets (H5), and that `rsi`/`rdx`/`r10` survive `syscall` (H4).

**Weighed:** all accepted. None changes behaviour except D1.

Round 3 is drawn after `experiri`, `peragrare` and `cohaerere` report, as one batch.

## The brand arrives (2026-10-04)

The builder: *"i also have a logo for wat... in watmin/algebraic-intelligence.dev... i think we can copy all of them?..
we can decorate our readme a bit too?"*
- **The files.** `brand/` holds that repository's `brand/` directory (at `cf1d1c8`): 12 files, copied verbatim. Their
  sha256 sums are recorded in the commit, and both repositories are Apache-2.0, copyright John Shields.
- **The layout.** `docs/LAYOUT.md` allows `brand/` at the top level, for image files only.
- **The README.** It shows the logo.
- **For Grok,** with the bare-reference check:
  - add `brand` to rule 1's allowed list in `tools/layout.sh`;
  - make rule 2's ELF scan and rule 8's syntax scan pass over `brand/` honestly (the SVG is text: 0 colon paths and 0
    arrows today);
  - add a mutant: a non-image file such as `brand/x.md`, which must be red. That is rule 1's "image files only".

### cohaerere: INCOHERENT; 3 Level-1 and 5 Level-2 findings, all confirmed and all accepted

- **F1 (L1):** "the eight rules" in the brief and the expectations against LAYOUT's nine, so row 0 promised one mutant
  per rule while rule 9 had none.
- **F2 (L1):** LAYOUT says `tools/` never builds, yet the seed was decoded once by `tools/check/hex-check.py`.
- **F3 (L1):** the brief's blast radius omitted `fuzz-hex0.py`, which row 12 requires.
- **F4 (L2):** "whitespace" is used undefined in the exit-4 row (vertical tab and form feed are exit 4, not skipped).
- **F5 (L2):** a comment "runs to the end of the line", but CR does not end one; only the brief said LF.
- **F6 (L2):** row 9 was described as a human reading, while "every row is a command".
- **F7 (L2):** two different documents were each called "read first".
- **F8 (L2):** rung 1 was named "hex1/hex2".

**Fixed by me, in my own documents:**
- F1: "every rule", and row 0 names its rule-9 and brand mutants.
- F2: LAYOUT rules 4 and 7 and the brief now DECLARE the seed's one decode as the single exception: the bootstrap of
  the root of trust, after which the seed reproduces itself.
- F3, F6, F7 and F8 as stated.
- F4 and F5 in the brief's own wording.

**For Grok (round 3):** F4 and F5 in `ladder/0-hex0/README.md` and the source header. Write "whitespace (exactly
space, tab, CR, LF)", and say a comment runs "to the next LF; a CR does not end it".

## R6 extended received (2026-10-04)

The bare-reference check is in, and its mutant is red naming rule 9. The rewritten quotations in LAYOUT and this
document keep the rule's meaning ("the name, a space, then digits"), and they are accepted. Verify then stopped on rule
1 at `brand/`. That is not a defect in the strike: `brand/` arrived in `9fa2eb5` while the strike ran. Its gate change
is "The brand arrives", above. Do that, then run verify to the end.

### peragrare, on the fuzz (row 12): the corpus does NOT span the instrument's discrimination space

**The census.** Anchor passed (populated, empty, and moving 267 of 267). 2,000 members, none dropped. 7 axes in 4
grids, derived from `reference()`'s branches: decoder state × event, high × low digit class, hex character × nibble
position, and reject byte × state. 553 cells: 331 read, 13 hollow, 180 empty (20 filed, 160 with no hypothesis), and
29 exempt as covered elsewhere (rows 3 and 4 decode the seed's own source). **33 findings.** All 33 hypotheses were
refuted by targeted runs (all 484 digit pairs, 228 reject bytes after a pending nibble, 15 comment-while-pending
inputs). The seed is right today, and the gate would not see a regression in these cells.

**The ones that matter most:**
- **The fuzz compares decoded bytes on only 4 values** (`00`, `41`, `42`, `AA`). Its random cases hit a reject within a
  byte or two, so status-0 cases come almost only from forced literals.
- **No gate reads the decoded value of a lowercase digit.** `ladder/0-hex0/tests/lower.hex0` is `61 62`, decimal digits
  whose output happens to spell "ab". Confirmed by my own reading. The fixture is named for what it never tests.
- **A comment between a byte's two digits** (state comment-while-pending) is visited by no instrument: 11 cells. The
  defects hiding there include clearing the pending flag on a comment, and testing pending before comment.
- **Reject bytes after a pending nibble** (`0x2F`, `0x40`, `0x80`, `0xFF`) are unvisited. A range check applied only
  to the high nibble would hide there.
- **Assumption 4 is broken:** the instrument reads OUT and ignores it on any non-zero status. OUT after a refusal is
  unspecified (conferre D3), so nothing checks it.
- **The discriminating mutant is caught by status alone.** No mutant proves the BYTE comparison discriminates.

### experiri: the declared surface IS fully reachable; 0 findings

The calibration passed (2 cells, 4 drives). The roster was 16 declarations, read from the header and the README, which
agree verbatim, and the input alphabet was probed exhaustively: all 256 bytes, splitting 6 skipped, 22 digits and 228
invalid, exactly as declared. 31 cells, every one drove and discriminated. A seccomp fault injector it wrote
(`/var/tmp/wards-hex0/experiri/drv/fault.c`) reached every failure site no ordinary input can: `fstat` on IN and on OUT,
`fchmod`, `read`, `write`, `close`, `ftruncate`. Each exits its declared status, and each exits 0 once the fault is
removed.

## Round 3 — the wards' findings, as one strike (2026-10-04)

The seed behaves exactly as declared, and every ward that drove it agrees. What the wards found is in how the seed
uses memory, how its source teaches an auditor, what its contract leaves unsaid, and where its gate is blind. Do these
after "The brand arrives".

- **R7 — the `fstat` buffer must hold a `struct stat` (conferre D1, nesciens H4).** Reserve at least 144 bytes
  before passing `rsp` to `fstat`, so nothing is written past what the seed reserved. Correctness first. If the seed
  then exceeds 512 bytes, report the size. Row 10's 512 is the orchestrator's number, not a principle: it moves with a
  stated reason before the code is contorted to fit it.
- **R8 — the source teaches an audit (conferre D2, nesciens H2, H4, H5, H7, H8).**
  - State the coordinate system for branch targets once, or make them file offsets.
  - Prefix each instruction comment with its offset, and give each block a heading (`# ### open IN`, …).
  - Declare AT&T syntax, and name the exit convention (push the status, jump to the exit; success enters with
    `edi = 0`).
  - State `p_filesz` as a sum (`0x78 + code = 511`).
  - Say which registers survive `syscall`, where `st_dev` and `st_ino` sit (`+0`, `+8`), and why `fchmod` precedes
    `ftruncate`.

  Row 9's mechanical comparison must keep working.
- **R9 — the contract states what a refusal leaves behind (conferre D3).** Say plainly what "total" means: every
  failure stops with a named status. Say what OUT holds after a refusal: none created, empty, or the bytes decoded so
  far, per status. Put it in the README, the header and the brief's table.
- **R10 — the README teaches (nesciens R1–R5, cohaerere F4, F5).**
  - A usage line and the platform.
  - One clause each for "ladder", "rung" and "seed", with a pointer to the design.
  - A byte's two digits may be split by whitespace or a comment.
  - "Whitespace (exactly space, tab, CR, LF)".
  - A comment runs "to the next LF; a CR does not end it".

  Make the same two wordings in the header.
- **R11 — the gate asks the questions it skipped (peragrare).**
  - `tests/lower.hex0` must contain lowercase digits.
  - Add fixtures for a comment between a byte's two digits, and for a reject byte after a pending nibble (`0x2F`,
    `0x40`, `0x80`, `0xFF`).
  - Rebalance the fuzz generator so most cases succeed and their bytes are compared across all 256 values, both cases,
    and separators or comments between digits.
  - Make the reference predict OUT after a refusal (R9), and compare OUT on every status.
  - Add a second discriminating mutant that only the BYTE comparison can catch (for example a lowercase offset off by
    one), and keep the status mutant.
- **R12 — the fault paths become rows (experiri).** Track a fault injector under `tools/check/`. Build it into `out/`
  with `gcc`, which `docs/MACHINE.md` lists. Add verify rows driving each failure site (`fstat` IN and OUT, `fchmod`,
  `read`, `write`, `close`, `ftruncate`) to its declared status, each with the fault-removed control. A refusal path
  only a ward has ever exercised is a path the next edit can break unseen.

After round 3: the orchestrator re-runs everything, casts `circumspicere` (last), and then `vigilia` with every ward's
full text. Then the seed lands.

## Round 3 received; my re-run on the 514-byte seed (2026-10-04)

`SCORE-hex0.md` "Round 3" covers R7–R12 and the brand gate. On my own runs:
- `tools/verify.sh`: ok, rc 0. It covers 16 layout mutants, rows 1–13 including the 7 fault rows with controls, and a
  byte mutant with 1,395 disagreements.
- My decode is identical to the seed; two generations are identical; `LOAD` is `0x202` (514 bytes).
- `sub $0x90,%rsp` at `+00c2` reserves exactly the 144 bytes `fstat` writes.
- My fuzz, generator seed 3, 20,000 cases: 0 disagreements.

**Row 10's ceiling moved from 512 to the measured 514, for the stated reason:** a `struct stat` buffer that fits needs
the imm32 form of `sub`. Correctness came first; the number was mine.

Next: `vigilia`, the full watch, on the rung. Every ward musters by the target's kind, each with its COMPLETE signed
text, and `circumspicere` comes last.

## vigilia on the 514-byte seed (2026-10-04) — DIVERGES: 36 L1 + 63 L2 across 19 wards

Cast per the spell: 18 inward wards in parallel, then `circumspicere` last. Each agent fetched its COMPLETE ward from
the signed channel (spawned agents were first probed and proven able to reach it), reading the rung cold. The wards
mustered by kind:
- the universal code set: intueri, solvere, conformare, purgare, struere, sequi, temperare;
- exigere;
- the conditional wards whose triggers fired: mora, experiri, peragrare;
- spec: cernere, probare, conferre;
- tests: complectens, vocare;
- docs: nesciens, cohaerere;
- circumspicere.

Not mustered: secare (no parallel primitives), excusare (no suppressions or runes), perspicere (no typed code),
partire (solvere reported no conflicting braids).

```
vigilia on ladder/0-hex0 + its gate
  experiri     : CONVERGED
  probare      : 1 L2        conferre    : 1 L2        cernere   : 2 L2        nesciens : 2 L2
  temperare    : 1 L2        mora        : 1 L1, 1 L2  sequi     : 4 L2        solvere  : 4 L2
  purgare      : 1 L1, 5 L2  complectens : 1 L1, 2 L2  vocare    : 3 L1, 1 L2  cohaerere: 3 L1, 3 L2
  conformare   : 3 L1, 4 L2  struere     : 3 L1, 8 L2  exigere   : 4 L1, 1 L2  intueri  : 4 L1, 9 L2
  peragrare    : 13 L1, 10 L2                          circumspicere : 4 L2
Aggregate: 36 L1 + 63 L2; DIVERGES.
```

**Where the findings live:**
- **No L1 is against the seed's bytes.** Every ward that drove or read them found the bytes right: encodings,
  reachability (150 of 150 instructions), register threading, the `fstat` bounds under gdb, and every status at every
  site, including what OUT holds.
- **The L1s are:**
  - **The gate's blindness, shown with mutants.** A seed with `ftruncate` moved before `fchmod` passes the whole gate
    (peragrare built it). No row stages a pre-existing OUT before a failure, or compares OUT after one. CR inside a
    comment, VT/FF, an odd digit count after real bytes, and argc 0 or 4 are all never exercised.
  - **The tools.** `hex-check.py` decodes in text mode, so it disagrees with hex0 on CR and crashes on non-UTF-8: found
    by four wards. Layout rule 7 fails open when grep returns 2. The fault injector assumes fds 0–2 are open and uses
    unchecked `atoi`. `verify.sh`'s header claims it builds only the seed and leaves the tree alone. A stale comment.
    The mutant failure messages are ambiguous.
  - **My documents.** The trust wording contradicted itself; F8 was unfixed in DESIGN; there were stale `seed/` paths;
    "checked in beside the binary"; "the only build"; CRAWL's deferrals.

**Fixed by me, in my own documents and repository files, before round 4:**
- **The trust wording,** now one phrase everywhere: "the one binary not built from source: the seed, written as
  commented hex so every byte can be audited by hand".
- **DESIGN-the-ladder.md.** Rungs 0, 1 and 2 are distinct. The seed's path is `ladder/0-hex0/hex0`. A rung's binary
  goes to `out/`. The syntax translation is a named ladder step. Totality's kernel bounds are stated (a signal, a
  blocking FIFO).
- **LAYOUT.md.** "Only RUNG build"; rule 7 admits a check's own instruments in `out/`.
- **BRIEF-hex0.md.** Its scope adds `fault.c`, and the wording is "none of them builds a rung".
- **CRAWL-the-subset.md.** Its deferrals become open questions Q1–Q5, bounded to before wat0's brief. Arena against
  counts is wat0's brief's row. The ladder section points to DESIGN.
- **`.gitattributes` and `.gitignore`.** `ladder/0-hex0/hex0 binary`, `*.hex0 text eol=lf`, `__pycache__/`.

## Round 4 — make the gate prove what the seed already does (2026-10-04)

The seed is right. What is not yet exemplary is the gate's ability to show it. Each item cites the wards that found
it. The section above holds every finding in full.

- **R13 — the seed refuses a non-regular OUT** (circumspicere C-2). `fchmod` changes a device's or FIFO's mode before
  hex0 refuses it; as root, `hex0 x /dev/null` would make `/dev/null` 0755. Test `S_ISREG` on OUT's `st_mode` (offset
  24 of the `fstat` slot) before `fchmod`, and refuse with status 3, leaving it unchanged. This is the only change to
  the seed's behaviour this round. Re-audit every offset and jump.
- **R14 — the contract states what it does not cover** (circumspicere C-1, C-6, C-7; conferre; cernere; nesciens;
  sequi; intueri; probare).
  - **Wording** in the README, the header and the brief:
    - status 7 applies only once OUT opened, and a read-only same file is status 3, unchanged;
    - a comment runs "to the next LF or end of input";
    - mode 0755 holds whenever OUT was opened, on every row;
    - a signal (SIGXFSZ under `ulimit -f`) ends hex0 with no status, and a FIFO or terminal IN can block;
    - 144 bytes is the x86-64 ABI's `struct stat`, not "this machine";
    - "every jump target" is relative to the code.
  - **Labels and register tables:**
    - register table in the header and the README: `rbp`/`r8` (IN's `st_dev`/`st_ino`) and `rcx`;
    - the three exit entry points;
    - the loop head;
    - the in-comment handler;
    - the success path;
    - the status-4 push.
  - **Provenance:** the README names `hex0.hex0` and how anyone verifies the binary from it.
  - **Trust wording:** use the trust phrase above in the README and the header.
  - **Fixtures:** `tests/exit42.hex0`'s comments point to the README rather than restating the language.
- **R15 — the gate stages and compares OUT everywhere** (peragrare, vocare, sequi, struere, conformare).
  - Every refusal and fault row runs against a pre-existing OUT with known bytes, and also against an absent OUT. It
    compares OUT's existence, bytes and mode against the README row.
  - **Prove it:** peragrare's truncate-before-fchmod mutant, `/var/tmp/vigilia-hex0/peragrare/mutant-trunc-first`,
    must be red.
  - **New fixtures:**
    - a CR inside a comment;
    - VT and FF (exit 4);
    - a TAB and non-ASCII bytes inside a comment;
    - `41\r\n42`;
    - `414` (exit 5, OUT `A`);
    - argc 0 and 4 (exit 1, OUT not created);
    - a read-only same file (3, unchanged).
- **R16 — the fuzz.**
  - A missing OUT is `None`, distinct from empty, and the reference states existence.
  - The generator reaches CR, TAB and non-ASCII inside comments, VT/FF, and odd counts after decoded bytes.
  - Drop the subprocess `timeout=30`; it polls with sleeps (mora), and the outer guard bounds it.
  - Resolve the fixture path from `Path(__file__)`.
  - Rename the mutant to a "letter offset", and make `NEAR` say what it is near.
  - Give each failure kind its own exit code, and print the BYTES on a bytes-only disagreement.
- **R17 — `hex-check.py` decodes as hex0 does** (four wards). Read bytes; `decode` returns rather than exits; statuses
  4 and 5 mirror hex0's; `--lint` prints the line numbers. The two `verify.sh` strippers become one helper on the same
  byte-exact decoder.
- **R18 — `layout.sh` cannot fail open** (conformare, circumspicere, solvere, purgare, temperare, intueri).
  - Every probe's return code is checked: grep 2, `od` on unreadable files, `find` inside process substitution.
  - Rule 7 states and checks what it means (cp, mv, dd, install, `-o` into `out/`, not only redirects), with the
    declared allowance for a check's own instruments.
  - Rule 2 refuses any tracked binary outside `brand/` and the seed, not only ELF.
  - It takes a ROOT argument.
  - The brand check is named as part of rule 1 in LAYOUT.
  - Remove the dead branches.
  - Read magic bytes with a builtin, not one `od` per file.
- **R19 — `verify.sh` never touches the live tree or index** (sequi, solvere, struere, complectens, intueri).
  - Run every layout mutant against a scratch COPY of the tree (`cp -a` under `/var/tmp`; no worktrees, by standing
    rule), through `layout.sh ROOT`.
  - Each mutant has a label printed in its failure.
  - A truthful header.
  - `PYTHONDONTWRITEBYTECODE=1`.
  - Row 9's comparator moves into `tools/check/`, checks the `+offset` prefixes, and is proven red by a comment mutant.
  - Row 8 gets a mutant too.
  - Row 10 reads `p_filesz`/`p_memsz` from the binary and requires both to equal the file's length (solvere showed a
    stale header passes today).
  - `timeout --verbose`.
  - Delete the stale comment.
  - Fault artifacts live in the sandbox.
- **R20 — `fault.c`.** Open `/dev/null` onto any closed fd among 0–2 (struere reproduced the misfire). `strtol` with
  end checks, and refuse errno 0. Remove the dead includes; rename the shadowed `fd`.

After round 4: my re-run, then `vigilia` again with every ward, until it converges or each remaining finding carries a
rune whose reason earns it. Then the seed lands.

## Round 4 received; reproduced on my runs (2026-10-04)

- **Read.** R19 is in: `verify.sh` copies the tree to `/var/tmp/hex0-verify-tree` and runs every mutant there through
  `layout.sh ROOT`; `PYTHONDONTWRITEBYTECODE=1`; `timeout --verbose`. R20 is in: `fault.c` uses `strtol` and reopens
  `/dev/null` onto any closed fd among 0–2. R16 and R17 are in: a missing OUT is `None`, the fixture path comes from
  `__file__`, and `hex-check.py` decodes bytes, returns statuses 0, 4 and 5, and its `--lint` prints line numbers.
- **My runs.**
  - `tools/verify.sh`: ok, rc 0.
  - `git status --porcelain` and the index are byte-identical before and after verify, and no `__pycache__` appears.
  - My decode is identical to the 537-byte seed, and two generations are identical.
  - My fuzz, generator seed 4, 20,000 cases: 0 disagreements.
- **Credited.** peragrare's truncate-before-fchmod mutant is red. The seed refuses a non-regular OUT with status 3,
  leaving it unchanged.

## R21 — one contract, per-target implementations (2026-10-04)

The builder: *"should we have this organized such that other architectures can land later?... yeah - after grok returns
let's get this prepped"*. hex0's input language and statuses are architecture-free; its code and syscalls are
x86-64 Linux. `docs/LAYOUT.md` rules 2 and 3 and `DESIGN-the-ladder.md` "Targets" now say:
`ladder/<n>-<name>/{README.md, tests/, <arch>-<os>/}`, one committed seed per target, `uname` spelling.

- **Move** the source and the seed to `ladder/0-hex0/x86_64-linux/` (`hex0.hex0`, `hex0`). The rung keeps `README.md`
  and `tests/`. The README and the header say the contract is the rung's and the code is the target's.
- **The gate selects targets.** The host target is `$(uname -m)-$(uname -s | tr A-Z a-z)`.
  - **Every target directory present:** decode and byte identity (rows 1, 2), the fixpoint where executable (row 3),
    lint, row 9 (with the disassembler for that architecture), and row 10's header check.
  - **Every target the host can execute:** the contract rows (fixtures, the fuzz, faults, OUT staging).
  - **A target the host cannot execute** is reported as "not executed on this host", never silently green.
- **Layout.** Rule 2: one committed binary per target, at `ladder/0-hex0/<arch>-<os>/hex0`. Rule 3: a rung holds
  README, `tests/`, and `<arch>-<os>/` directories only. Add mutants:
  - a seed at `ladder/0-hex0/hex0`, outside a target;
  - a target directory with no source;
  - a badly named target (`X86-64`);
  - a second committed binary inside a target.
- **Every path** under `tools/` and in the excursus documents moves with it; the rule-9 bare-reference and syntax rules
  still hold. Rung 0's README remains the contract's only home.

Then the orchestrator re-runs everything and casts `vigilia` on the final layout.

## R21 received; reproduced on my runs (2026-10-04)

The source and the seed live at `ladder/0-hex0/x86_64-linux/`; the contract (README, `tests/`) stays on the rung.

**My runs:**
- `tools/verify.sh`: ok, rc 0, with 22 labelled layout mutants, including R21's four.
- `git status --porcelain` is identical before and after.
- My decode is identical to the 537-byte seed, and two generations are identical.
- `aarch64-linux: not executed on this host` shows the cannot-execute branch, reported rather than silently green.

I widened `.gitattributes` to `ladder/0-hex0/*/hex0 binary`, so any future target's seed is protected.

**Next:** `partire` on `tools/verify.sh` (the builder: *"our wat/tools/verify.sh is already showing signs it needs to
be modular?"*), so the gate splits along its true seams before rungs and targets multiply it. Then `vigilia` again on
the result.

## The checkpoint, and what committing revealed (2026-10-04)

The builder: *"we should commit and push often - we don't have any CI yet... we should view github as our DR
(disaster recovery) site"*. Until now the rung was uncommitted until landing. **From here on, every round that passes
the orchestrator's re-run is committed and pushed as a checkpoint, labelled NOT landed.** The landing is a separate
commit after vigilia converges. The checkpoint is `579778d`.

Committing revealed two failures:
- **My `.gitattributes` corrupted the DR copy.** `*.hex0 text eol=lf` stored `crlf.hex0` and `crlf-two.hex0` without
  their CRs, the bytes those fixtures exist to test. Fixed in `c485276`: fixtures are `-text` (byte for byte), rung
  sources are LF, and the seed is binary. The committed bytes now equal the disk.
- **The layout gate went red the moment `tools/` was tracked:** rule 8, `tools/verify.sh:460`, an arrow inside an
  error message. Rule 8 scans only TRACKED files, so the gate never examined its own scripts, or any strike file,
  until commit. A gate whose verdict depends on what happens to be staged is a gate that passes the uncommitted work
  it exists to check.

## R22 — the gate modular, self-contained, and blind to nothing on disk (2026-10-04)

From `partire` (SPLIT: three cuts) and what committing revealed.

- **Cut 1: `tools/check/layout-mutants.sh SCRATCH_DIR`.**
  - It holds the baseline `layout: ok`, the copied tree, `mutant_expect`, every mutant, the post-run `layout: ok`, and
    the check that the live tree was untouched.
  - It takes a seed from the tree's `ladder/0-hex0/*/hex0`, not the host's.
  - The rung-gap mutant is computed as the highest rung number + 2; `ladder/2-skip` breaks the day hex1 lands.
  - It has one reason to change: `docs/LAYOUT.md`'s rules, in the same commit.
- **Cut 2: `tools/check/seed-audit.sh <ladder/0-hex0/<arch>-<os>> <sandbox> [--size N]`.**
  - It is the ONE copy of rows 1, 2, 9, 10 and 11, plus row 9's comment mutant, for every target.
  - Delete the host's duplicate rows. They have drifted: only the host copy pins the size, and only it has the row-9
    mutant.
  - It runs nothing it decodes.
- **Cut 3: `tools/check/hex0-contract.sh <hex0> <target-src> <ladder/0-hex0/tests> <sandbox>`.**
  - It holds rows 3–8, 12 and 13, and their mutants, for a target the host can execute.
  - A later rung gets its own `<rung>-contract.sh`; this one does not move.
- **The driver, `tools/verify.sh`.** It handles the sandbox, the guards, host detection, and the loop over rungs and
  targets dispatching to the modules. `die` and `guard` go in a sourced `tools/check/gate-lib.sh`: one definition of
  how the gate fails and times out, not four copies.
- **Self-contained.** The truncate-before-fchmod mutant is derived DURING the run, from the seed, by a byte patch
  (the way `fuzz-hex0.py` flips bytes, asserting its pattern matches exactly once). It is no longer read from
  `/var/tmp/vigilia-hex0/peragrare/`, a ward's scratch directory that my round-4 item R15 named. That was my brief's
  defect, and on a fresh clone the gate is red. LAYOUT rule 7 now says it: "the gate depends on nothing outside the
  repository".
- **Blind to nothing on disk.**
  - `layout.sh`'s rules 2, 8 and 9 examine every file in the tree that is not git-ignored (the files a commit could
    carry), not only tracked ones.
  - A mutant proves it: an UNTRACKED tools file containing a colon path must be red.
  - Then fix the false positive at `tools/verify.sh:460` (write "to", not an arrow).
- **The syscall ABI.**
  - The fault rows' raw x86-64 syscall numbers, and the syscall allow-list's `open`, become the target's: a small
    table per target directory.
  - This is not a cut while there is one target, so it is bounded: the brief that adds the second executable target
    carries it as a row.
  - Name the table's place now, in DESIGN's Targets section.

Then the orchestrator re-runs everything, checkpoints, and casts `vigilia` on the modular gate.

## R22 received — and the modular gate FAILS OPEN (2026-10-04)

**R22's shape is right:**
- `tools/verify.sh` is a 66-line driver;
- `gate-lib.sh`;
- three modules: `layout-mutants.sh`, `seed-audit.sh` (which never runs the seed) and `hex0-contract.sh`;
- the truncate mutant patched during the run;
- rules 2, 8 and 9 see untracked files;
- the syscall table's place named.

**But the driver ignores every module's exit status.** `guard` (`gate-lib.sh`) returns the callee's status. The driver
calls `guard 180 tools/check/layout-mutants.sh "$SANDBOX"`, and every other module the same way, with no `|| die`, and
the script has no `set -e`.

**Shown, not argued.** I ran the gate in a fresh copy that holds exactly the files a commit would carry, in a new
repository without `c45603e`:
- `layout-mutants.sh` died: `verify: layout rc 1 (layout: rule 6: git diff failed …)`;
- the driver went on to print every row and `verify: ok`, rc 0.

Rule 6 failing there is correct, because that repository has no history (a real clone carries it). What failed is the
driver. So R22's `verify: ok`, including my own run on the real tree, shows only that the driver reached its last
line. `partire` named the test that catches this ("stub modules that exit 0 or 1, and assert the dispatch"), and I did
not require it in R22. My miss.

## R23 — the gate fails closed, by construction (2026-10-04)

- **Remove the class, not the instance.** `guard` itself dies when the callee fails or times out:
  `timeout … "$@" || die "<module or command> rc $?"`. Every module call inherits that, with nothing to forget at a
  call site.
- **Where a caller deliberately expects a failure,** as the mutant runners and the refusal fixtures do, give it a
  separately named helper that returns the status (`run_status`), so the default is the safe one.
- **Prove the driver.** Add `tools/check/driver-test.sh`: run `tools/verify.sh` against stub modules in a scratch copy.
  - Each stub module exits 1 in turn: `layout-mutants`, `seed-audit`, `hex0-contract`.
  - Each must make the driver exit non-zero and print which module failed.
  - Then one stub that never returns must be killed by its guard and reported.
- **Prove a fresh clone.** The gate's own last row clones the repository into the sandbox with `git clone` (full
  history, so rule 6 holds) and runs the layout check there. That catches any dependency on untracked state.

The R22 tree is checkpointed now, for disaster recovery, with this defect named in the commit.

## R23 received — the gate fails closed, proven by breaking it (2026-10-04)

`guard` dies on any failure or timeout (`gate-lib.sh`), and `run_status` is the named helper for an expected status.
`tools/check/driver-test.sh` proves that each module's exit 1, and a hang, are fatal. A fresh `git clone` runs the
layout check.

**My own injections,** in a full copy of the repository, independent of Grok's driver test. Each made `tools/verify.sh`
exit 1, with a message naming the module:
- `seed-audit.sh` replaced by `exit 1`;
- `hex0-contract.sh` replaced by `exit 1`;
- `layout-mutants.sh` replaced by `exit 1`;
- one byte of the seed flipped (offset 300).

The real run on the live tree: `verify: ok`, rc 0, and `git status` identical before and after.

**For the next watch (L2):** `HEX0_DRIVER_TEST=1` silently skips the driver test and the fresh-clone row. It is a
nesting hook, but a silent skip is the same shape as the fail-open just removed; it should announce itself.

## The second vigilia (2026-10-04) — in flight

Cast at checkpoint `1e41957`, after R23. 19 inward wards, each fetching its full signed text:
- intueri, solvere, conformare, purgare, struere, sequi, temperare;
- exigere, mora, excusare (triggered by five `shellcheck disable=SC1091` lines), experiri;
- peragrare, once per instrument: fuzz, contract, seed-audit, layout-mutants, driver-test;
- cernere, probare, conferre, complectens, vocare, nesciens, cohaerere.

circumspicere is cast last. Reports are recorded here as they arrive.

- **probare: 1 L1, 3 L2.**
  - **L1:** a FIFO OUT hangs instead of exiting 3, because OUT is opened without `O_NONBLOCK`, so `open` blocks
    waiting for a reader. Measured: `mkfifo f; hex0 in f` timed out. The header and the README promise "a device or
    FIFO is refused", and only `/dev/null` is tested. The likely fix: `O_WRONLY|O_CREAT|O_NONBLOCK` (`0x841`). A FIFO
    with no reader then fails `open` (ENXIO), and one with a reader fails `S_ISREG`: status 3 either way. Prove it with
    a fixture.
  - **L2:** "mode 0755 on every later status" should say "once `fchmod` has succeeded".
  - **L2:** the same-file check (7) precedes the non-regular check (3); state the order.
  - **L2:** the contract is written twice (README and header), with nothing comparing them. The header could keep only
    what the bytes need and point to the README.
