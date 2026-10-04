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
- **nesciens: 0 L1, 3 L2.** The bytes audit holds by hand: header, offsets, encodings, jumps, syscalls, constants.
  - **L2:** the README presents "running this seed on its source and comparing" as equal to the independent decode.
    A fixpoint proves self-consistency, not trust: a seed that recognises its own source would pass it. Say so.
  - **L2:** the precedence of 7 over 3 (`hex0 /dev/null /dev/null` exits 7) is unstated.
  - **L2:** there is no exact verification command a stranger can run from the README.
- **exigere: 1 L1, 3 L2.**
  - **L1:** `DESIGN-the-ladder.md` describes `syscalls.tsv` as if it exists and is read. It does not exist yet; the
    fault rows and the allow-list hardcode the numbers.
  - **L2:** the `HEX0_DRIVER_TEST` silent skip is still open (the R23 note).
  - **L2:** the aarch64 and riscv rows in DESIGN are half-filled. Use "not a target until a machine is in hand".
  - **L2:** "the invariant is checked by the gate" (16-byte alignment) is not a check yet. Bind it to "the first rung
    with a `call` carries an alignment row".
  - **Routed elsewhere:**
    - `layout.sh:236,249` still allows `out/fault`, a stale exemption (the injector now builds in the sandbox);
    - EXPECTATIONS row 13 still says `out/fault`;
    - `SCORE-hex0.md:3` "Nothing was committed" is stale against the checkpoints;
    - `verify.sh:66` probes a nonexistent `aarch64-linux` every run.
- **cernere: 1 L1, 1 L2.** Everything traces to x86-64 and the Linux ABI, including `st_mode` +24 and S_IFMT/S_IFREG.
  The FIFO OUT hang is reproduced independently (L1). L2: `fuzz-hex0.py:31` says "'x' follows 'f'", which is false.
- **conferre: 1 L1, 3 L2.** The fstat slot ends exactly at argc (gdb). The FIFO OUT hang (L1).
  - **L2:** "0755 on every later status" contradicts the failed-fchmod row.
  - **L2:** the precedence of 7 over 3 is unstated.
  - **L2 (new):** "a read-only same file is status 3" holds only without CAP_DAC_OVERRIDE. Under root (`unshare -r`) the
    open succeeds and the result is 7, still untouched. Qualify it.
- **intueri: 4 L1, 17 L2.**
  - **L1:** the 0755 sentence.
  - **L1:** the FIFO OUT bound.
  - **L1:** the stale `out/fault` allowance in `layout.sh:236,249`, which keeps a real hole in rule 7.
  - **L1:** `verify.sh`'s header says it never modifies the tree, but `fuzz-hex0.py:240` writes
    `ladder/0-hex0/tests/fuzz-disagree.hex0` into the repository on a disagreement.
  - **L2s:**
    - headings: read setup; keep IN's identity; comment start;
    - "row N" labels with no pointer to EXPECTATIONS;
    - a dead `old` variable in `seed-audit.sh`;
    - `skip=120` unnamed;
    - opaque names: `same`, `pair`, `fix_ok`;
    - fds 3 and 4 assumed, unstated;
    - the hidden `py.bin` channel;
    - the opaque trunc-mutant hex;
    - fuzz flag and kind names;
    - raw byte literals;
    - `ALLOWED` used as `EXPECTED`;
    - the aarch64 self-probe;
    - mutants hard-coding today's docs.
- **solvere: 5 L1, 7 L2.**
  - **L1, worst:** a module's library location depends on how it is called. `here=$(dirname …)` is used after `cd`,
    so `gate-lib.sh` fails to load from any other working directory. `die` is then undefined, every `|| die` is
    "command not found", and the module EXITS 0. Measured: `seed-audit.sh … --size 999` from `/var/tmp` exited 0, and
    `layout-mutants.sh` printed fake reds. Resolve the root absolutely, source from it, and fail if the source fails.
  - **L1:** rule 5 reads the `Exit status:` block from a TARGET source. Adding a second target makes the gate red
    ("found 2"), against LAYOUT's promise. The contract check belongs to the README only.
  - **L1:** `hex0-contract.sh` claims to be per-rung but embeds x86-64 facts (syscall numbers, fds, mutant bytes).
  - **L1:** the fuzz writes into the live repository (as intueri found).
  - **L1:** the layout mutants hard-code `docs` contents; adding the next excursus breaks the counter-gap mutant
    (measured).
  - **L2:** the `py.bin` channel; the seed layout written in four places; the target-name grammar written three
    times; the decoder's scan loop duplicated; the stale `out/fault` exception; the driver self-testing in the driver;
    `argc0.c` as a heredoc.
- **cohaerere: 1 L1, 4 L2.** The earlier five fixes hold.
  - **L1:** EXPECTATIONS row 13, BRIEF:49 and LAYOUT rule 2 put the fault injector in `out/`; rule 7 (new) puts it
    in `/var/tmp`. Fix row 13 and scope rule 2 to "binaries a rung produces".
  - **L2:** rule 7, MACHINE:3 and BRIEF:12 state "never builds" absolutely, without pointing to the seed exception
    (rule 4).
  - **L2:** DESIGN:46-47 speaks of `syscalls.tsv` in the present tense, and rule 3 does not admit a TSV in a target.
  - **L2:** DESIGN:32 and :131 say "the one committed binary"; LAYOUT says one per target.
  - **L2:** DESIGN:26 "Given: Linux on x86-64" predates Targets. It should read "each target's architecture".
- **complectens: 2 L1, 7 L2.**
  - **L1:** layout failures are silent. `layout-mutants.sh:20,173` sends layout's output to scratch files, guard dies
    first, and the sandbox is deleted, so the broken rule is never named.
  - **L1:** the `py.bin` cross-module channel misattributes cause ("row 12 seed changed").
  - **L2:** about 19 row-labelled `die` messages are unreachable after `guard`, so failures name the command, never
    the row. Row 11's lint line numbers are deleted with the sandbox.
  - **L2:** two argc checks cannot fail, and one is mislabelled.
  - **L2:** the "status mutant" accepts any kind of disagreement.
  - **L2:** the row-9 mutant never reads why it went red.
  - **L2:** "then reverted" is unproven; the leftover checks look at the live tree, which mutants never touch.
  - **L2:** the argc and same-file trios are inlined.
  - **L2:** lint has never been shown failing.
- **vocare: 0 L1, 5 L2.** The checks call from the caller's side, and every README status has a fixture or a fault.
  - **L2:** `hex0-contract.sh:344` reads seed-audit's `py.bin`. Run alone, the contract dies with a false "row 12 seed
    changed". It also compares against the decoded source, not against the seed as it was before the fuzz.
  - **L2:** the fuzz writes `fuzz-disagree.hex0` into the live tree.
  - **L2:** the argc-1 "OUT not created" check at :150 and :157 tests a path that hex0 is never given.
  - **L2:** there is no FIFO-OUT row. With a reader, the result is rc 3 and mode unchanged; with none, hex0 blocks.
  - **L2:** `verify.sh:66` probes a target that does not exist, and is a false red on an aarch64 host.
  - **Notes:** fuzz's "independent" reference uses the same algorithm as hex-check. fault.c cannot fail the Nth call.
    No check flags a fixture that is not named.
- **sequi: 3 L1, 8 L2.** The seed's register thread holds on every path.
  - **L1:** modules cd and then source `$here/gate-lib.sh`. Run from `wat/tools`, `die` and `guard` are not found, and
    the module exits **0** after printing "row 1/2/11 ok" against empty files.
  - **L1:** the `py.bin` coupling (as vocare reports).
  - **L1:** fuzz derives ROOT from `__file__` and writes into `tests/`. The git-status before/after check cannot see it
    once the file exists.
  - **L2:** the contract needs `out/`, which only the driver creates.
  - **L2:** layout.sh's `FIND_LIST`/`VISIBLE` temp files leak on every `fail`, about 20 per run into `/tmp`.
  - **L2:** the fuzz work directory is outside the sandbox; a KILL leaves it behind.
  - **L2:** `HEX0_SANDBOX` and the `*_GUARD` knobs are undocumented, and `HEX0_SANDBOX=.` makes `rm -rf` delete the
    repo.
  - **L2:** one verdict covers two trees: the fresh clone is HEAD, while everything else checks the working tree.
  - **L2:** the seed's register table omits rsi and rdx. fstat OUT relies on rsi left by fstat IN.
  - **L2:** the code base is written three times: e_entry, `skip=120`, `CODE_BASE`.
  - **L2:** helper functions write globals.
- **conformare: 2 L1, 7 L2.** The seed is conformant; every finding is in the gate.
  - **L1:** a failing layout or lint check prints only `rc 1`. The diagnostic goes to a redirected file that the
    sandbox trap deletes. Shown with a STRAY file and a lint break. The proposed fix is one labelled checked run in
    gate-lib, which captures output and replays it on failure.
  - **L1:** `fill_find` reports every find failure as rule 2, including failures inside rules 1, 3, 5 and 9.
  - **L2:** about 19 row labels are unreachable after `guard`.
  - **L2:** the row-9 and trunc-first mutants accept any failure.
  - **L2:** the check tools' exit codes collide: a Python traceback is 1, the same as a real failure; hex-check's
    usage and missing-file codes invert hex0's; fault.c's codes 93–98 are undocumented; `cd || exit 2` exits silently.
  - **L2:** the 0755 sentence contradicts status 3.
  - **L2:** status meanings are written in three copies, and rule 5 compares only the numbers.
  - **L2:** fuzz writes into the tree.
  - **L2:** steps that are unchecked or have no timeout.
- **experiri: CONVERGED.** All 32 cells were driven and discriminated, with its own ptrace injector (fail the Nth
  syscall).
  - Every status cause was driven against every OUT prior state, with the outcome as declared. FIFO and pty OUT give
    rc 3 with the mode unchanged; the pty case proves S_ISREG precedes fchmod.
  - Not driven: block-device OUT, FIFO or terminal IN, and errnos other than EIO, EPERM and ENOSPC.
- **purgare: 2 L1, 14 L2.** The seed has no dead instruction, write or branch (CFG walk: 156 of 156).
  - **L1:** the `skip_execution` checks at `verify.sh:55` and :63–66 test nothing; :66 is a false red on aarch64.
  - **L1:** the `fault.c` / `out/fault` allowance in layout.sh is dead, and it is a standing hole in rule 7.
  - **L2:** the 19 rc checks after guard.
  - **L2:** the argc-one and argc-0 assertions on paths hex0 is never given.
  - **L2:** dead regexes in syscalls-check.
  - **L2:** the `old` variable at `seed-audit.sh:62`.
  - **L2:** the non-x86 seed-audit path cannot succeed.
  - **L2:** fuzz's `reference()` always says the file exists, and an early return is dead.
  - **L2:** fault's ERRNO is always 1.
  - **L2:** redundant writes and patterns in layout.sh.
  - **L2:** duplicate post-checks in layout-mutants.
  - **L2:** the seed's `xor r14d` and `xor r10d` need a safety-margin comment.
  - **L2:** the driver-test guard.
- **excusare: 8 L1, 1 L2.** 14 exemptions weighed; 5 hold.
  - **L1:** five reasonless `# shellcheck disable=SC1091` lines (×5). The fix is `# shellcheck source=…`. Shellcheck is
    not a gate; gate-lib has no shell directive.
  - **L1:** the `out/fault` allowance. It is a substring match, so `cp … out/hex1 # fault.c out/fault` stays green.
  - **L1:** brand/ skips rule 2's ELF check as well as its NUL check. `brand/evil.png` with ELF magic stays green.
  - **L1:** the `out/*` skip only ever applies to force-added files, so `git add -f out/h1` stays green.
  - **L2:** `HEX0_DRIVER_TEST=1` also silently skips the fresh-clone check.
- **struere: 4 L1, 14 L2.** Every seed jump target was checked by hand; it has no per-instruction defect.
  - **L1:** `fill_find` reports the wrong rule (shown).
  - **L1:** rule 5 counts Exit-status blocks per rung, so a second target is red (shown).
  - **L1:** nothing checks that `out/` is untracked, although LAYOUT claims it is enforced (shown).
  - **L1:** fuzz writes into the tree (shown).
  - **L2:** the `py.bin` coupling.
  - **L2:** fault.c's ERRNO is masked to 16 bits, so `65536` injects nothing; it should reject values outside
    1..4095.
  - **L2:** fault.c's fd-layout guarantee is not in its header.
  - **L2:** the global temp files leak.
  - **L2:** the stale `out/fault` hole.
  - **L2:** the dead rc checks.
  - **L2:** steps without guard.
  - **L2:** the `old` variable.
  - **L2:** hex-check's `digit_text` duplicates the tokenizer.
  - **L2:** `reference` exists=True.
  - **L2:** the contract's stringly expectation tokens (a typo falls through to cmp).
  - **L2:** `skip_execution` is a predicate that prints.
  - **L2:** the seed comments use two address spaces (file offset and target). The fix is objdump `--adjust-vma`.
  - **L2:** `HEX0_SANDBOX` is passed to `rm -rf` unchecked.
- **temperare: 1 L1, 1 L2.** The gate takes 34 s; layout.sh runs 26 times at 1.25 s each. The seed's byte-at-a-time
  I/O is exempt by design: self-build is 11,728 syscalls in 0.01 s. It lacks a stated cost ceiling (not counted).
  - **L1:** layout.sh spawns processes per file, in rule 2 (`tr|cmp`), rule 8 (two greps) and rule 9 (one grep),
    and lists files three times. That is about 0.88 of 1.33 s per run, and it grows with the file count; batching
    measures about 0.02 s per scan. The estimate is about 40% of the gate. Keep grep's error codes distinct (xargs
    returns 123 for both no-match and error).
  - **L2:** the two fuzz self-tests run all 2000 cases after the first qualifying disagreement (case 1043 and case
    49). Stopping early saves about 3.7 s. Otherwise, rune the counts as evidence.
- **mora: 4 L1, 4 L2.** One wait primitive, `timeout -s KILL`: an event wait with a timer arm. The seed has no waits;
  its read loop ends on EOF.
  - **L1:** a module killed by its timeout leaves its nested guards running after the verdict. Each `timeout` takes its
    own process group. Reproduced with `CONTRACT_GUARD=5`: a fuzz run was alive after verify exited. Survivors can
    write into the tree, race the sandbox `rm -rf`, and leak `hex0-fuzz-*`. The honest shape is to run each module
    in a group or cgroup it cannot leave and wait until that group is empty.
  - **L1:** the nested budgets are inverted. Each outer guard is smaller than the worst case of the guards inside
    it (layout-mutants 180 against 1500 s; contract 180 against 1200 s). So the inner literals never decide anything,
    and the outer kill is what triggers the escape above.
  - **L1:** a timer kill counts as "mutant red" for row 9 and for trunc-first. Reject rc 137 and require the refusal
    text.
  - **L1:** the driver-test hang proof never observes the kill. With the stub changed to `exit 3`, it still printed
    "hang is killed". Assert rc 137 and the KILL message.
  - **L2:** no duration carries a reason or a measured basis; headroom is 8x to 80x.
  - **L2:** the environment knobs move only the outer timers.
  - **L2:** the fuzz has one 120 s deadline over 2000 cases. A hang does not name its input, and a KILL skips cleanup.
  - **L2:** the hang stub is `sleep 300`, itself a guessed duration. Block on an event that never arrives instead.
- **peragrare: 32 L1, 1 L2.** One cast per instrument; all five green on a copy. Census scripts are in
  `/var/tmp/vigilia2-hex0/peragrare/census/`. The five gaps claimed fixed were re-derived and hold, except argc: the
  argc-0 OUT assertions are vacuous, and the row labelled "argc 1" stages argc 2.
  - **fuzz (2 L1):** (status 5, pending, comment open at EOF), with and without bytes before, is never visited.
    Hypothesis refuted on this seed: `4#x` and `414#x` give rc 5.
  - **contract (5 L1):**
    - FIFO OUT is unvisited. CONFIRMED: it blocks in open and is killed with rc 137.
    - A write or read failure after one or more bytes is never staged (4 cells). Every fault fails the first call,
      so "keeps the bytes written before" is asserted only at 0. On this seed, `ulimit -f 1` gives rc 6 and keeps
      1024 bytes, so the cell can be built.
  - **seed-audit (4 L1):** the comparisons are never shown going red:
    - row 1 seed-differs: the checkpoint's byte-flip proof is not committed;
    - row 9 offset and count: `zip()` truncates silently;
    - row 11 bare.
  - **layout-mutants (19 L1, 1 L2):**
    - 7-allowlist CONFIRMED.
    - 5b-many CONFIRMED: a second target holding its own Exit-status block.
    - 17 latent checks are never exercised: 1b, 3a, 3b, 4a, 5a, 6b; the 7 tee/mv/dd/install/-o regexes; 8 arrow; 9b,
      9c, 9d, 9f, 9h.
    - L2: 3d is hollow, because the mutant reads only the rule number.
  - **driver-test (2 L1):** seed-audit hang and contract hang are unvisited. They cannot be filled as configured: the
    30 s module guard exceeds the 20 s hang bound.
- **circumspicere (cast last): 1 L1, 5 L2.**
  - **L1:** the "independent" decode is not independent. Row 2's `xxd` only packs digits chosen by
    `hex-check.py --digits`, and every source-to-seed path goes through one tokenizer, which the README also hands to
    strangers. MACHINE:27 and DESIGN:35-36 claim independence. An external decode matches today:
    `sed 's/[#;].*//' hex0.hex0 | xxd -r -p | cmp - hex0`. Make that the row-2 decode and the README's verification
    line.
  - **L2:** the sandbox is a fixed name in sticky `/var/tmp`. `rm -rf` failure is unchecked, then `mkdir -p` adopts a
    directory another user owns, and the gate compiles and executes there. Concurrent runs delete each other's
    sandbox. The fix is `mktemp -d`, and refuse an existing or foreign `HEX0_SANDBOX`.
  - **L2:** the SIGXFSZ sentence depends on the inherited disposition. With the default, rc is 153 and a core is
    dumped; with it ignored, rc is 6 and 1024 bytes are kept (CPython parents ignore it). State both, and add a row
    for each.
  - **L2:** the gate needs a full clone (rule 6 reads `c45603e`), a git worktree rather than an archive, an executable
    `/var/tmp`, and `ptrace_scope` ≤ 1. Each fails closed, but MACHINE states none of them.
  - **L2:** `.gitattributes` pins the rung's bytes but not the gate. Under `core.autocrlf=true`, every tools script
    checks out as CRLF and dies with `bash\r`. The next rung's extension gets no eol pin. The fix is a first line
    `* text=auto eol=lf`, keeping the overrides after it.
  - **L2:** the public claims run ahead of the repo:
    - the GitHub description is stale ("algebraic cognition");
    - the README says "watc … compiles itself", but there is no watc;
    - the README shows no "not landed" status;
    - LAYOUT's "a red build" has no CI or hook behind it, and the branch is unprotected.
  - **L3 (not counted):**
    - the ELF has no `PT_GNU_STACK`;
    - opening a device OUT is not a no-op: there is no `O_NOCTTY`, and opening it can change tty, tape or DTR state;
    - a default ACL survives the fchmod;
    - the seed has no provenance outside the repo: commits are unsigned and there are no tags;
    - RECOVERY.md is not listed as a standing doc;
    - SIGXFSZ dumps core;
    - `out/` holds the stale files `pre600` and `fault`.

### The second vigilia's verdict — DIVERGES

experiri alone CONVERGED. Every inward ward that found an L1 found it in the gate or the documents, never as a seed
defect, with one exception: the seed's open of OUT has no `O_NONBLOCK`, so a FIFO OUT blocks, and the README promises a
status for every failure. Round 5 is drawn from the deduplicated findings above.

## Round 5 — one seed fix; the gate says why it failed, owns its time, and is proven at every check (2026-10-04)

Drawn from the second vigilia, deduplicated. Each item names the wards behind it; the entries above hold every
finding in full. The seed changes in ONE place (R24). Everything else is the gate and the documents.

- **R24 — a FIFO OUT is refused, not waited on** (probare, cernere, conferre, intueri, vocare, peragrare).
  - Open OUT with `O_WRONLY|O_CREAT|O_NONBLOCK` (`0x841`). A FIFO with no reader then fails `open` (ENXIO), and one
    with a reader fails `S_ISREG`. Both are status 3, with OUT unchanged.
  - Re-audit every offset and jump. If the size changes, change `--size` and every place that names 537.
  - Add contract rows for a FIFO OUT with no reader and with a reader. Both must give 3, with the mode unchanged.
- **R25 — the contract says exactly what holds** (probare, nesciens, conferre, conformare, intueri, circumspicere).
  - Write "0755 once `fchmod` has succeeded", not "on every later status".
  - 7 is tested before 3: `hex0 /dev/null /dev/null` exits 7. Say so.
  - "A read-only same file is 3" holds only without CAP_DAC_OVERRIDE. As root it is 7, still untouched.
  - SIGXFSZ: with the default disposition, hex0 is killed (rc 153, core). With it ignored, the result is status 6
    and the bytes written are kept. Add a contract row for each.
  - The fixpoint proves self-consistency, not trust. Say so beside the independent decode.
  - Opening a device OUT can change device state (no `O_NOCTTY`). "Unchanged" means mode and bytes.
  - The header keeps what the bytes need and points to the README for the contract. Status meanings live in the
    README only, and the header's `Exit status:` block is a pointer, so they cannot drift.
  - Put a `safety-margin` note on the `xor r14d` and `xor r10d`.
  - Complete the register table: rsi from fstat IN is reused by fstat OUT; rdx is unset by design for open IN.
  - Comment addresses use ONE space: file offset. disasm-check and seed-audit use `--adjust-vma`.
- **R26 — the independent decode is independent** (circumspicere C2-1; struere).
  - Row 2 becomes `sed 's/[#;].*//' hex0.hex0 | xxd -r -p`, compared byte for byte with the seed. It shares no code
    with `hex-check.py`.
  - The README's verification line for a stranger is that one-liner.
  - MACHINE and DESIGN describe what each decode is.
  - `hex-check.py` has one tokenizer, which both `decode` and `--digits` consume.
- **R27 — every failure names its row and shows its evidence** (conformare, complectens, struere, purgare, sequi,
  mora).
  - Add one helper in `gate-lib.sh`: `check LABEL SECS -- cmd…`. It captures stdout and stderr, and on failure or
    timeout it dies with the label, the rc, whether the timer fired, and the captured output.
  - Every guarded step uses it. Delete the about 19 unreachable `rc=$?; … || die` lines.
  - Every currently unguarded step goes through it too: dd, objdump, xxd, the heredoc pythons, the `hex0-contract`
    xxd and :304.
  - Check tools document their exit codes. A Python traceback is a distinct code (an uncaught exception is never
    "check failed"). hex-check's usage and missing-file codes are stated, not mirrored by accident. fault.c's
    header lists 93–98 and the fd layout it guarantees.
  - `fill_find` takes the rule number, as `visible_list` does.
- **R28 — the gate owns its processes and its time** (mora, sequi, circumspicere, struere).
  - **Remove the nesting, not the escape.**
    - Only steps are guarded. The driver calls modules without a timer.
    - Every step inside a module is guarded (R27), so no module can hang unbounded.
    - With one level of timers, no inner timer can outlive an outer kill, and no budget can be inverted.
    - Prove it: after a step's timer fires, no descendant of that step is alive.
  - Write the durations once, in `gate-lib.sh`, with the measured basis beside them. One knob scales all of them.
  - The fuzz bounds each case and, on a hang, names and keeps the input that hung.
  - The hang stub blocks on an event that never arrives, not on `sleep 300`.
  - Hang proofs assert that the timer fired: "timed out" in the message.
  - The sandbox:
    - `mktemp -d /var/tmp/hex0-verify.XXXXXX` by default;
    - `HEX0_SANDBOX` must not exist yet and must be under `/var/tmp`;
    - nothing is adopted;
    - concurrent runs cannot collide.
  - The fuzz work directory lives inside the sandbox.
  - layout.sh's temp files are in a `trap`-cleaned directory under its caller's scratch, not `/tmp`.
- **R29 — modules are self-contained and never touch the repo** (sequi, solvere, vocare, struere, intueri,
  complectens).
  - Each module resolves the repo root absolutely before any `cd`, sources gate-lib from it, and exits 2 if the
    source fails.
  - Each module creates every directory it writes to; it needs nothing the driver set up (`out/`).
  - The contract hashes HEX0 at its own start and compares at the end. No `py.bin`.
  - fuzz writes a disagreement into the sandbox it is given, and prints the path.
  - `hex0-contract.sh` holds no x86 facts. Syscall numbers, fds and mutant bytes come from the target directory, as
    a declared per-target file. This makes DESIGN's `syscalls.tsv` real, with rule 3 admitting it. Otherwise DESIGN
    stops naming it.
- **R30 — layout.sh has no allowances it cannot justify** (excusare, purgare, struere, intueri, cohaerere, solvere,
  peragrare, temperare).
  - Delete the `fault.c` / `out/fault` allowance.
  - Rule 2 checks ELF magic everywhere, including `brand/`. Only the NUL check is exempt there.
  - A tracked `out/` path is a rule-1 failure, and the `out/*` skip is deleted.
  - Rule 5 compares the README's status set with each target's statuses. Under R25 the target holds a pointer, so a
    second target cannot make it red.
  - Replace the `shellcheck disable=SC1091` lines with `# shellcheck source=tools/check/gate-lib.sh`, and give
    gate-lib a `# shellcheck shell=bash` line. Do not add a shellcheck gate this round.
  - Each rule scans in one batched pass over a list fetched once, so a grep error stays distinct from no-match.
  - Remove the dead patterns and the redundant writes.
  - Mutants derive the docs counters from the tree; they do not hard-code today's docs.
- **R31 — every comparison is shown going red** (peragrare, complectens, vocare, purgare).
  - **seed-audit:**
    - row 1 with a seed byte flipped;
    - row 9 offset and count, where a count mismatch must be fatal (no silent `zip`);
    - row 11 with a bare hex line.
    Each mutant greps for its own refusal text, and a timer kill never counts as red.
  - **contract:**
    - read and write failures after one or more bytes, for absent and existing OUT (fault.c learns to fail the Nth
      call);
    - true argc 1;
    - delete the vacuous argc-0 and argc-1 OUT assertions;
    - the trunc-first mutant greps its reason.
  - **fuzz:** force (status 5, comment open at EOF) with and without bytes before. Each self-test stops at its first
    qualifying disagreement and says so.
  - **layout:**
    - a mutant for every `fail` site peragrare listed as unvisited (1b, 3a, 3b, 4a, 5a, 6b, 7 tee/mv/dd/install/-o,
      8 arrow, 9b, 9c, 9d, 9f, 9h);
    - an ELF in `brand/`;
    - a force-added `out/` file;
    - a `fault.c … out/fault` line;
    - a second target with its own source;
    - each mutant greps the specific check's text, not only the rule number.
  - **driver:** hang proofs for seed-audit and the contract as well.
  - The post-mutant leftover checks are deleted; the git-status comparison covers them.
- **R32 — the driver tests nothing it does not have** (purgare, vocare, excusare, struere).
  - Delete `verify.sh:63-66` and the dead `|| die` at :55. `skip_execution` becomes an `is_host` predicate plus a
    report line.
  - Prove the skip path in driver-test with a copied tree that holds a non-host target.
  - `HEX0_DRIVER_TEST=1` skips only the driver test and prints what it skipped. The fresh-clone row always runs.
  - The final line names what was verified: the working tree, and the HEAD clone.
- **R33 — the documents agree with each other and with the repo** (cohaerere, exigere, circumspicere, nesciens).
  - EXPECTATIONS row 13, BRIEF:49 and LAYOUT rule 2: the injector lives in the sandbox. Scope rule 2 to "binaries a
    rung produces".
  - "Never builds", in rule 7, MACHINE:3 and BRIEF:12, points to the seed exception (rule 4).
  - DESIGN: one committed binary per target; "each target's architecture"; aarch64 and riscv are "not a target until
    a machine is in hand"; the 16-byte alignment check is bound to "the first rung with a `call`".
  - MACHINE states what the gate needs: a full clone, a git worktree, exec on `/var/tmp`, and `ptrace_scope` ≤ 1.
  - `.gitattributes` starts with `* text=auto eol=lf`, keeping the binary and `-text` overrides after it. Prove it
    with a clone under `core.autocrlf=true`.
  - README:
    - drop the claim that watc exists;
    - add a status line ("rung 0: in weigh, not landed");
    - list RECOVERY.md among the standing docs, as LAYOUT does.
  - LAYOUT's "a red build" means "red when `tools/verify.sh` runs, which is before every checkpoint". There is no CI
    yet.
  - SCORE:3's "Nothing was committed" is stale.
  - Fix `fuzz-hex0.py:31` ("'x' follows 'f'").

**Not in this round:** the GitHub repository description, which is stale ("algebraic cognition"). Changing it is
the builder's outward call, so it is asked, not briefed. The builder chose the new wording, and it was set on
2026-10-04: "A Lisp for Linux programming, bootstrapped from a hand-auditable hex seed, with no Rust, no C and no
libc."

After round 5: my re-run, with every module broken in turn; a checkpoint; then vigilia again.

## Round 5 received — weighed and checkpointed as `3e54e66` (2026-10-04)

Grok's run was red, and its SCORE named the cause: the clone rows clone HEAD, which did not yet have the new
`.gitattributes` line. I did not re-run that red.
- **Probing the cause:** I committed the candidate tree inside a scratch copy (`/var/tmp/r5-weigh`) and ran verify
  there. rc 0.
- **Breaking it, in that copy.** Each injection went red and named its cause:

  | injection | what the gate printed |
  |---|---|
  | `seed-audit.sh` → `exit 1` | `verify: tools/check/seed-audit.sh rc 1` |
  | `hex0-contract.sh` → `exit 1` | `verify: tools/check/hex0-contract.sh rc 1` |
  | `layout-mutants.sh` → `exit 1` | `verify: tools/check/layout-mutants.sh rc 1` |
  | seed byte 300 flipped | `verify: row 1 cmp` |
  | a top-level `STRAY` | `layout: rule 1: top-level name not in the layout: STRAY`. The diagnostic now survives. |
  | seed-audit run from `/var/tmp` with `--size 999` | rc 1 at row 10. It fails closed from another cwd. |
  | `HEX0_SANDBOX=.` | `HEX0_SANDBOX must be under /var/tmp`. The repo is intact. |
- **In the code:**
  - modules run without a timer; only steps are timed;
  - `mktemp` sandbox;
  - fuzz keeps a disagreement in the sandbox;
  - no `py.bin`;
  - no `out/fault` allowance;
  - absolute root and `|| exit 2` on the source.
- **After the checkpoint:** live `tools/verify.sh` exits 0, `git status` is identical before and after, and no
  sandbox is left behind.

## R34 — the gate is green before the commit, and leaves nothing behind (2026-10-04)

- **The clone rows test the candidate, not HEAD.** The question they answer is "does this tree survive a clone".
  Today they clone HEAD, so the gate cannot be green before the commit it is meant to approve.
  - Copy the working tree into the sandbox (`cp -a`).
  - Run `git add -A` and a commit there, using the sandbox's own index and never the live one.
  - Clone that commit plainly and with `core.autocrlf=true`, then run the layout check on each.
  - The final line says "working tree, committed in the sandbox and cloned".
  - Prove it: a `.gitattributes` change in the working tree only makes the autocrlf row pass before any live
    commit, and reverting it makes the row go red.
- **No core dump per run.** The default-SIGXFSZ row writes a core into the journal on every gate run (three today,
  in `coredumpctl`). Run that row with `ulimit -c 0`; it is still killed, rc 153. The `File size limit exceeded` line
  that bash prints for the deliberate kill goes into that row's captured output, not the gate's stderr.
- **Replayed nested output keeps its line breaks.** Grok's red printed
  `verify: non-host target: driver rc 1 verify: autocrlf clone rewrote a tools script` on one line.

After R34: my re-run, a checkpoint, then the third vigilia.

## R34 received — weighed (2026-10-04)

- **Live run, before any commit:** `tools/verify.sh` rc 0 with empty stderr. `git status` and the `.git/index` hash
  are identical before and after, and no `hex0-verify.*` sandbox is left. The gate is now green on the very tree it
  approves.
- **The SIGXFSZ default row:** the journal still logs the crash event, but `coredumpctl info` shows
  `Storage: none`. No core is kept.
- **Breaking it:** in a scratch copy, removing `* text=auto eol=lf` from the working tree alone, with no commit,
  makes the gate go red with `autocrlf clone rewrote a tools script`. The candidate row tests the working tree.
- **A concern withdrawn:** from reading the code, I expected the sandbox commit to need a configured git identity. On
  a probe with an empty HOME and `GIT_CONFIG_NOSYSTEM=1` the gate is green, because git falls back to user@host.
  Not a finding.
- **My own probe error:** the first round of probes wrote their output files into the tree under test, and the gate
  correctly went red on rule 1. Probe output lives outside the tree under test. I re-ran them that way; the results
  above are from the re-run.
- **Small, for the vigilia:** `git -C "$candidate" config commit.gpgsign false` and the no-attribute `grep -v`/`mv`
  run outside `check`.

Checkpointed. Next: the third vigilia.

## The third vigilia (2026-10-04) — in flight

Cast at checkpoint `9b334d1`, after round 5 and R34. The same 19 inward wards as the second, each fetching its full
signed text. Each derives its findings fresh and checks every round-5 claim rather than trusting it. peragrare adds
a sixth instrument: verify's candidate and clone rows. circumspicere is cast last. Reports are recorded here as they
arrive.
- **exigere: 0 L1, 4 L2.** Every second-vigilia exigere item is confirmed fixed: `syscalls.tsv` is real and read; the
  driver-test skip is announced; the target rows are bound; the routed items are closed.
  - **L2:** RECOVERY:35 says green is "`verify: ok` with rc 0", but since R32 the last line is
    `verify: working tree, committed in the sandbox and cloned`. It is the orchestrator's file, so I fixed it myself
    in the commit that records this entry.
  - **L2:** MACHINE describes tools for work that does not exist (C comparisons, perf reports, watc's output), and
    omits gcc's real use: the fault injector and the argc and sigxfsz helpers.
  - **L2:** DESIGN:122 "the invariant is checked by the gate as the rungs grow" is present tense for a check that does
    not exist. Bind it to "the first rung with a `call` carries an alignment row in its EXPECTATIONS".
  - **L2:** LAYOUT:65 "There is no CI yet". The "yet" came from R33's own wording. Write "There is no CI."
  - **L3 (not counted):**
    - watc is given two homes: LAYOUT's top-level `watc/` and DESIGN's `ladder/<n>-<name>/`;
    - LAYOUT:77 omits RECOVERY;
    - LAYOUT rule 5 claims more than layout.sh checks;
    - DESIGN:80 "already designed" for watc's register partition;
    - DESIGN:47 gives the TSV column order backwards;
    - `.gitignore:9`;
    - "wait status 153" against "shell status 153" (the wait status is 25 without a core);
    - the dead `ALLOWED` list in syscalls-check;
    - stale files in `out/`.
- **nesciens: 0 L1, 2 L2.** The cold walk holds.
  - The README's `sed | xxd | cmp` one-liner runs clean.
  - Every status probed matches.
  - The header, walked byte by byte, matches readelf.
  - An independent objdump matches all 156 instruction comments.
  - The second vigilia's three nesciens items hold.

  Findings:
  - **L2:** a stranger cannot reproduce the disassembly from the documents. `objdump -d hex0` prints nothing (there
    are no sections). Following the header's `--adjust-vma` hint on the file disassembles the ELF header as code. The
    working recipe (`dd skip=120` plus `--adjust-vma`) lives only in seed-audit. Give the one-liner
    `objdump -D -b binary -m i386:x86-64 --start-address=0x78 hex0`, which was measured to match all 156.
  - **L2:** the header says "wait status 153" and the README says "shell status 153". The raw wait status is 153 only
    when a core is reported; here systemd-coredump's pipe reports one even with `ulimit -c 0`. The shell status is 153
    everywhere.
  - **L3 (not counted):**
    - `.gitattributes:6`'s "a CR changes what the rung decodes" is false for rung 0;
    - LAYOUT:18 omits RECOVERY;
    - "7 before 3" is too broad, because a failed open or fstat of OUT is 3 before the same-file test;
    - forward references ("rung", "watc", hex-check's path);
    - the expected results live in `hex0-contract.sh`, which no README points to;
    - `ff.hex0` is easily confused with `reject-ff.hex0`;
    - neither README says how to run the gate.
- **probare: 0 L1, 2 L2.** The bytes have substance:
  - 178 data lines carry all 537 bytes, and every one is commented.
  - The 156 instruction comments are machine-checked.
  - The 22 ELF field comments hold by hand.
  - R24, R25 and R26 hold, measured.

  Findings:
  - **L2:** R25 does not hold. The header says "this target does not restate them", yet lines 17–59 restate the
    input language, the open order, 7-before-3, SIGXFSZ, and what OUT holds after each status. Nothing compares the
    two copies, and they have already drifted (wait/shell 153). Measured: a mutant header line `status 4: untouched`
    passes both layout.sh and seed-audit. The header keeps only what the bytes need.
  - **L2:** two headings mislabel their bytes. `### ftruncate` also heads the read-loop setup at 0x153–0x15c, and
    `### fstat OUT` heads the save of IN's identity at 0xdf–0xe3. This was the second vigilia's intueri L2. I did not
    draw it into round 5; that was my omission.
  - **L3 (not counted):**
    - "7 before 3" (as nesciens);
    - "as root" should be "with CAP_DAC_OVERRIDE": `unshare -r` with the capability dropped gives 3;
    - "pop into edi" is `pop %rdi`;
    - rcx is not named as the digit scratch register;
    - `exit42.hex0:1` carries its stale name;
    - the gate prints "no core" and then replays timeout's "dumped core" line.
- **experiri: 0 L1, 3 L2.** All 62 cells were driven and discriminated with its own ptrace injector. Calibration
  passed, and a `je`→`jmp` mutant proves the driver can fail.
  - Every cause was driven against an absent and an existing OUT, including failures after 2 bytes, and each matched
    the README table.
  - R24 holds: a FIFO with no reader gives ENXIO then 3; with a reader, S_IFIFO then 3, with no fchmod.
  - Precedence with a FIFO, a pty or `/dev/null` as the same file gives 7.

  The three L2s are drove-but-wrong-value divergences against the round-5 wording:
  - **L2:** the CAP_DAC_OVERRIDE sentence overclaims. With the capability, a root-owned file whose owner is not
    mapped (`unshare -r`) gives 3, and a read-only bind mount gives 3 (EROFS). The capability must be effective over
    that inode, and the mount must be writable.
  - **L2:** "7 is tested before 3" is false for fstat OUT. An injected fstat-OUT failure on the same file gives 3. The
    order is: open/fstat OUT (3), then same file (7), then not regular (3).
  - **L2:** the header's "wait status 153" (as nesciens and probare found). Driven: with RLIMIT_CORE=1 the wait status
    is `0x19`; the 153 seen here comes from the systemd-coredump pipe.
  - **L3 (not counted):**
    - a FIFO reader is released with EOF;
    - a lease holder gets SIGIO;
    - FIFO IN==OUT discards pending data;
    - row 6's "no core" checks only the cwd, while WCOREDUMP is still set.
- **complectens: 1 L1, 7 L2.** These second-vigilia items hold:
  - layout output is replayed;
  - `py.bin` is gone;
  - the unreachable dies are gone;
  - row 9's mutant greps its reason;
  - lint is shown red;
  - each mutant's reversion is proven, because layout must be ok on TREE after every mutant.

  Findings:
  - **L1:** "mutant row 1 (byte)" never runs row 1. It writes its own Python comparator, compares a flipped copy, and
    greps its own output. With row 1 and row 2 replaced by `true` and seed byte 10 flipped (a header byte row 9 does
    not see), seed-audit printed `row 1: cmp identical`, then `mutant row 1 (byte): red`, rc 0. A seed that differs
    from its source passes while the gate prints a red-proof for the deleted row. This breaks R31.
    - **My weigh missed it.** I credited the printed "mutant row 1: red" from the SCORE. My own byte-300 injection
      exercised the live row 1, not the mutant, so it could not have seen this.
  - **L2:** six comparisons can be neutered with the full gate still rc 0: row 2, row 10, contract rows 3 and 4, and
    the layout half of both clone rows. The noattr mutant re-implements the CR grep inline, inverted, instead of
    calling the row.
  - **L2:** driver-test's hang proof proves the stub's own timer: the stub calls `check … 2` itself. The driver has
    no timer, so a module blocking outside `check` hangs verify for good (a probe was killed at 45 s).
  - **L2:** gate-lib has no proof of its own: no test of `check`'s replay, of `reap_group` (R28's "no descendant
    alive"), or of `secs_of`'s refusal. An ad-hoc probe shows they work, so this is unproven, not broken.
  - **L2:** R27's "every unguarded step goes through `check`" does not hold. Heredoc pythons, the layout-mutants `cp`
    and git calls, and the FIFO reader are still bare. Measured: a generator failure was blamed on the comparator.
  - **L2:** `disasm-check.py:8` documents exit 99 for an unexpected failure, but it has no handler; a missing file
    exits 1, the same as a mismatch.
  - **L2:** the fuzz status mutant still accepts any disagreement kind; it is right today by the luck of case order.
    R31 was claimed but not implemented.
  - **L2:** the argc and same-file scenarios are still inlined. Round 5 never drew this; my omission.
  - **L3 (not counted):**
    - `prove_fail` does not grep `rc 1`;
    - the stub scaffold is written three times;
    - the row-9 mutant generators could share one helper;
    - `sleep 30` for the FIFO reader;
    - three layout fail sites are never visited;
    - the git-status comparison is vacuous if git fails.

  **Lesson for my weigh:** a printed "mutant …: red" is the executor's claim. Before crediting a mutant, I break the
  ROW it guards and watch the gate go red.
- **cohaerere: 0 L1, 9 L2 (INCOHERENT).** The second vigilia's five cohaerere fixes hold.
  - **L2:** the standing documents are listed three ways. LAYOUT:18 omits RECOVERY, and R33's "as LAYOUT does" was a
    false premise of mine.
  - **L2:** "7 before 3" (as experiri; fault-injected fstat OUT on the same file gives rc 3).
  - **L2:** "independent decoder" names two things. BRIEF:45 gives it to hex-check.py; MACHINE, DESIGN, README and
    EXPECTATIONS give it to sed|xxd.
  - **L2:** "the one binary not built from source" (DESIGN:8 and :32, README:32, the rung README, BRIEF, the header)
    against "one seed per target" (DESIGN:43, LAYOUT:31). R33 fixed only DESIGN:131.
  - **L2:** RECOVERY's green line. Already fixed in `74b3234`.
  - **L2:** layout scope is stated three ways. LAYOUT says "tracked" or "committed"; RECOVERY says "not git-ignored";
    the gate examines every name on disk for rule 1 and everything not ignored for rules 2, 8 and 9. Shown with
    STRAY, an untracked colon file, and `__pycache__`.
  - **L2:** who fetches a ward's text. WARDS says the orchestrator pastes it; RECOVERY says the agent fetches it.
  - **L2:** EXPECTATIONS says "written before the strike", but it has six later commits, and row 10 records history.
  - **L2:** "total" is bounded in DESIGN and unbounded in the rung README, the header and BRIEF.
  - **L3 (not counted):**
    - "worktree" in MACHINE means a working tree, against "never use worktrees";
    - wait/shell 153;
    - "no core" beside "dumped core";
    - BRIEF's blast radius is stale;
    - row 4 decodes via `hex-check --digits | xxd`;
    - EXPECTATIONS:3 "a command in verify.sh";
    - stale files in `out/` and `__pycache__`.
- **mora: 2 L1, 5 L2.** The direct question is answered: a step's timer kill leaves no descendant, for every command
  the gate runs. Measured: the fuzz with a forking fake hex0 left no process. Modules are untimed, so no budget is
  inverted.
  - **L1:** the hang proofs cannot tell a timer from any SIGKILL. "Timed out" is inferred from rc 137 alone, never
    from timeout's own "sending signal" line. A stub that runs `kill -KILL $$` (no hang) passed all three hang
    proofs. `exit 124` is also classed as timed out, and an OOM kill would be reported as a timeout. The second
    vigilia's mora L1 and R27/R28 do not hold.
  - **L1:** the fuzz names a hung input it has already deleted. `finally` unlinks the work directory, and verify's
    trap deletes the sandbox on a red too, so neither "hung on" nor "kept fuzz-disagree" exists after a red. R28's
    "names and keeps" does not hold.
  - **L2:** `HEX0_TIME_SCALE=0` disables every timer (`timeout 0`). A ward's probe hung on it.
  - **L2:** fuzz has its own unscaled `timeout=5` per case, a second timer level, and it is reported as rc 1, not
    "timed out".
  - **L2:** reap_group sleep-polls, about 2 s, and sees only the process group. A `setsid` child escapes.
  - **L2:** the "FIFO with a reader" row races the reader's open. It never flipped in 800 runs; the fix is
    `exec 3<>fifo` before the row.
  - **L2:** gate-lib's stated basis ("fuzz inside 120 s") contradicts DUR_LONG 90, and the measured time is 5.4 s.
  - **L3 (not counted):**
    - pgid reuse in reap_group;
    - `set -m` job notices on stderr;
    - a die inside the SIGXFSZ subshell is reported as rc 1;
    - the setsid escape.
- **solvere: 2 L1, 7 L2.**
  - **L1:** the header restates every status meaning while saying it does not (as probare). Measured: header status
    4 and 7 rewritten to contradict the README, and full verify rc 0. BRIEF:31 and :70 still instruct a third copy.
    R25 fails. The header shrinks to a pointer.
  - **L1:** x86 facts remain in the per-rung scripts:
    - `verify.sh:47` keys `--size 537` on the target name;
    - seed-audit maps arch to objdump, holds the x86 mutant text and a literal `+0078`;
    - fuzz's BOUND and LETTER are x86 opcode patterns.
    Measured: adding a `riscv64-linux` target gives `row 9: no disassembler mapped`, red. driver-test's non-host
    proof stubs seed-audit, so it hid this. R29 holds only for hex0-contract. Every per-target fact moves to
    `gate.tsv`.
  - **L2:** the contract finds `gate.tsv` through `dirname "$SRC"`, a hidden channel. `fact` and `nr_of` swallow awk
    failures. It should take the target directory, as seed-audit does.
  - **L2:** `out/` is a fixed-name channel shared by concurrent runs; a second run's row 3 broke the first (measured).
  - **L2:** the syscall set is written three times, and `ALLOWED` in syscalls-check is a dead literal.
  - **L2:** fuzz's reference uses the same algorithm as hex-check, line for line.
  - **L2:** the rung README holds x86 facts (registers, the 144-byte stat, offsets).
  - **L2:** tracebacks in syscalls-check and fuzz are rc 1. R27 holds only for hex-check and disasm-check.
  - **L2:** rule 3 accepts any non-`hex0` file as "the source" (a target with only `gate.tsv` is green). The
    target-name grammar is written three times.
- **purgare: 0 L1, 9 L2.** The seed holds no dead thought:
  - CFG 156 of 156 reachable;
  - every branch driven both ways;
  - the O_NONBLOCK change left nothing dead, and the FIFO-reader row discriminates (an S_ISREG `je`→`jmp` mutant is
    red 300 of 300).
  - The `xor r14d`/`r10d` pair is dead on Linux; NOPed, it is 2000 agree and self-builds identical. Its rune covers
    only one line, and its reason describes the encoding rather than the margin (L3).

  Findings:
  - **L2:** fuzz deletes the hung input it names (as mora found).
  - **L2:** fuzz's `exists` is a constant, so two arms and two counters are dead. This is the second vigilia's L2, not
    drawn.
  - **L2:** syscalls-check holds the dead `ALLOWED`, two dead regexes (0 of 11,967 lines), and an always-taken
    `execve` insert. This is the second vigilia's L2, not fixed.
  - **L2:** rule 3's "target has no source" can no longer fire; `gate.tsv` satisfies it. Measured: `git rm`
    `hex0.hex0` gives layout ok. (Also solvere.)
  - **L2:** the non-x86 seed-audit path cannot succeed, so row 10's empty-size path is dead. driver-test stubs
    seed-audit. (Also solvere.)
  - **L2:** R31's "post-mutant leftover checks deleted" does not hold; `layout-mutants.sh:317-324` still checks the
    live tree.
  - **L2:** the "no core" check cannot fail. It looks for a core file in the sandbox and the repo root; under a pipe
    `core_pattern` none is ever written.
  - **L2:** `disasm-check.py` documents 99 but exits 1 on a traceback (also complectens).
  - **L2:** steps that R27 claimed guarded are unguarded, and the mutant generators' "found nothing" exits are never
    read (also complectens).
  - **L3 (not counted):**
    - verify:44 is unreachable;
    - `HEX0_SCRATCH` is re-exported;
    - gate-lib's `124` disjunct is dead under `-s KILL`;
    - driver-test's guard;
    - fault ERRNO is always 1;
    - nine identical control runs;
    - a dead line in hex-check;
    - layout.sh dead patterns, redundant `rm`s, the visible list fetched three times;
    - unread TSV numbers;
    - a `__pycache__` from an importer outside the gate.
- **intueri: 1 L1, 14 L2.** What speaks:
  - the seed's per-instruction comments are matched to objdump;
  - the named entry points;
  - `check`, `run_status`, `reap_group` and the prove_* helpers;
  - most mutant labels;
  - the fault.c header.

  Findings:
  - **L1:** the "mutant row 1 (byte)" never exercises row 1 (as complectens). Measured: row 1 disabled and
    `hex-check.py` dropping a byte gives seed-audit rc 0.
  - **L2:** three seed headings do not say what their block does (`fstat OUT`, `ftruncate`, `comment`). This is the
    second vigilia's L2, which I did not draw and recorded no reason for.
  - **L2:** the `gate.tsv` keys `trunc_old`/`trunc_new` are opaque, and one thing has three names. No file documents
    the keys.
  - **L2:** the contract helpers `fact`, `assert_out`, `pair` and `fix_ok` are opaque, and so are the tokens `same`,
    `samebytes:755` and `empty`. Second vigilia, not drawn.
  - **L2:** `ALLOWED` is dead, and the docstring understates the check. Not drawn.
  - **L2:** the "status mutant" accepts any kind (measured: the letter mutant passes it at case 49, kind 5). The flag
    `--expect-disagree` names nothing.
  - **L2:** magic numbers: the kinds 3/4/5 double as exit codes, and the byte classes are raw decimals. Not drawn.
  - **L2:** the SIGXFSZ checks are labelled "row 6" (Format edges), and "no core" is printed beside "dumped core".
  - **L2:** disasm-check exits 1 on a traceback, and so do syscalls-check and fuzz.
  - **L2:** rule 7's "a rung's output" names both what is forbidden and what is permitted.
  - **L2:** the "fault allowance bypass" mutant names an allowance that no longer exists.
  - **L2:** RECOVERY's green line. Fixed in `74b3234`.
  - **L2:** the gate-lib timer comments do not support the numbers. `DUR_LONG` also times `cp -a`.
  - **L2:** `HEX0_DRIVER_TEST=1` reads as the opposite of what it does.
  - **L2:** no "row N" label points to EXPECTATIONS. Not drawn.
  - **L3 (not counted):**
    - wait/shell 153;
    - seed-audit's header claims mutants for rows 2 and 10;
    - fault.c fork returns 94;
    - one scratch directory has four names;
    - the rule-8 heading overclaims "Clojure/EDN";
    - LAYOUT:18;
    - rsi is called both "the stat buffer" and "the one-byte buffer";
    - a duplicate `layout: ok`;
    - gate-lib's "about 34 s".
- **conformare: 4 L1, 4 L2.** The seed's statuses conform, as does fault.c's set of codes.
  - **L1:** "timed out" is guessed from rc 124/137. `sh -c 'kill -9 $$'` and `exit 124` both print "timed out", and a
    hang stub that kills itself passes all three hang proofs (as mora). Decide the timer field from the captured
    `sending signal KILL` line.
  - **L1:** the fuzz never delivers its failing input. The hang file is deleted by its own `finally`, and
    `fuzz-disagree.hex0` is deleted by the sandbox trap (measured through a full verify). Fix: print the input bytes
    in the message; `check` replays it.
  - **L1:** a Python crash is reported as a failed check:
    - disasm-check, syscalls-check and fuzz exit 1 on a traceback;
    - fuzz's rc 1 means three different things;
    - layout's rule-2 heredoc crashed on a non-UTF-8 filename and was reported as an empty rule-2 violation.
    Only hex-check conforms.
  - **L1:** steps still run with no timer, and the driver relies on there being none. These are the heredoc pythons,
    the layout-mutants `cp` and git calls, and verify's clone-row lines. A shim making `python3 -` hang hung
    seed-audit with no verdict. verify:202 counts grep's rc 2 as "no CR" and passes.
  - **L2:** `run_status` is a second vocabulary with no label; seven callers each hand-write their own message. One
    `expect LABEL SECS WANT -- cmd` would close it.
  - **L2:** a bare `die` after `cmp -s` or `stat` prints only a label, with no got and no want, and the trap deletes
    the evidence.
  - **L2:** `HEX0_TIME_SCALE`: 0 disables the timers, and a non-number dies only inside a subshell, so the step then
    fails as rc 125.
  - **L2:** RECOVERY's green line (fixed in `74b3234`).
- **vocare: 1 L1, 6 L2.** The contract checks call from the caller's side, and all 21 fixtures run. Row 8 (strace),
  `gate.tsv`'s fds, and the binary mutants are legitimate audits.
  - **L1:** the row-1 mutant tests a stand-in (third independent report).
  - **L2:** the SIGXFSZ-default row greps bash's localized job notice. Under `de_DE` it goes red while hex0 behaves.
    Assert rc 153 only, or pin `LC_ALL=C`.
  - **L2:** "no core" cannot be observed under a pipe `core_pattern`.
  - **L2:** the README's root case (7) has no fixture, and the gate goes red as root. It can be fixtured with
    `unshare -r` (rc 7, unchanged).
  - **L2:** the clone rows do not check the fixture pin. With `.gitattributes`'s `tests/* -text` line deleted, verify
    is green, both clones hold `crlf.hex0` as LF, and the CRLF fixtures still pass, because `4\n1` decodes the same.
  - **L2:** the header restates the contract (fourth report).
  - **L2:** the rung README holds x86 facts (as solvere).
  - **L3 (not counted):**
    - the trunc mutant uses its own assertions;
    - the FIFO-reader race was reproduced in 2 of 300 replays;
    - the three hang proofs are one proof;
    - x86 mutant facts in shared tools;
    - nothing checks hex0's stdout or stderr;
    - unguarded heredocs.
- **cernere: 1 L1, 6 L2.** Everything traces:
  - the syscall numbers, 0x841, `struct stat` (144 bytes, +0/+8/+24) and S_IFMT/S_IFREG, against the uapi headers;
  - the ELF, against readelf;
  - 156 of 156 instructions;
  - the trunc mutant's re-derived displacements;
  - the timeout, git and objdump forms;
  - the `.gitattributes` ordering.

  Findings:
  - **L1:** the header restates the contract (fifth report). Measured: header status 7 rewritten and a `status 9`
    added, and full verify rc 0.
  - **L2:** the "argc 0" row is a phantom. Since Linux 5.18 an empty argv becomes `{""}`, argc 1; measured argc=1
    on 7.2.5. The row prints a case that was never run.
  - **L2:** `HEX0_TIME_SCALE`: 0 disables the timers; a leading zero is read as octal (`010` gives 8x); a bad value
    surfaces as rc 125. Require `^[1-9][0-9]*$` and validate once.
  - **L2:** fuzz deletes the hung input it names.
  - **L2:** disasm-check documents 99 but exits 1 on a traceback, and so does syscalls-check.
  - **L2:** the row-1 mutant does not run row 1.
  - **L2:** the O_NOCTTY reason is wrong. O_NOCTTY only affects acquiring a controlling tty (for a session leader
    without one); driver side effects such as DTR or tape rewind happen regardless. State the side effect without the
    false cause.
  - **L3 (not counted):**
    - fault.c closes fds only below 256 when NOFILE is 65536 or more (measured: fd 300 survives); `close_range` would
      fix it;
    - "only without CAP_DAC_OVERRIDE" (EROFS, immutable);
    - the seccomp filter does not check `arch`;
    - the FIFO-reader race;
    - "depends on nothing outside the repository" against MACHINE;
    - rule 7 greps ignored files.
- **excusare: 2 L1, 9 L2.** 26 exemptions weighed and 17 hold. Its summary line says "7 L2" but it lists nine, so the
  nine are recorded.
  - **L1:** the rule-5 "pointer" allowance is a stale guard (the header restates the contract, the sixth report).
    Measured green: a header `status 9:`, a one-line `Exit status: … 9`, a blank comment line after the heading, and a
    lowercase `exit status:`.
  - **L1:** the non-host skip lands a contract-violating seed green. An `x86_64-freebsd` target whose close-failure
    status is 9 printed "not executed on this host", and verify was rc 0. Under the gate's own injector it gives
    rc 9, a status in no README. The skip is keyed on the name, not on whether the host can execute it; its only
    reachable case is a binary this host can run.
  - **L2:** brand/ is checked by extension and byte-0 magic only. `logo-16.png` with the seed appended, `'P'` plus the
    seed, and a shell script named `.svg` are all green.
  - **L2:** the live `out/` holds a stale ELF (`fault`) and other old files. Rule 7's "holds only what a rung
    produces" is unchecked, and nothing empties `out/`.
  - **L2:** the `tests/` skip lets `BRIEF-hex1.md` and nested directories into a rung.
  - **L2:** hidden names are skipped (`.BRIEF.md` in a rung, a hidden rung `ladder/.1-hex1` that verify also never
    visits, a hidden excursus directory, `..stray`).
  - **L2:** `HEX0_DRIVER_TEST=1` is honoured at top level, so a user run skips the driver proof and still prints the
    full success line.
  - **L2:** the non-host and second-target proofs hold only with the modules stubbed. A real `aarch64-linux/hex0.hex0`
    makes verify red (layout-mutants' `mkdir -p` collides with it, and seed-audit dies next).
  - **L2:** the seed-decode exception's bounds are unchecked. A tools script that re-decodes the seed in place
    (making row 1 tautological), or writes `"$o/h9"`, is green.
  - **L2:** syscalls-check adds `execve` without bound. An appended `execve("/bin/sh")` passes row 8. Require exactly
    one, on the first line.
  - **L2:** `HEX0_TIME_SCALE=0` (fourth report).
  - **L3 (not counted):**
    - the shellcheck directives hold, and they are not suppressions;
    - `__pycache__`;
    - `--size` is a per-target fact;
    - rule 9's regex is case-sensitive.
- **conferre: 0 L1, 11 L2.** The seed matches its contract on every point compared:
  - all 156 instruction comments, every jump, S_ISREG, `0x841`/`0x1ed`, `p_filesz`, the register table, the classify
    ranges and the status order;
  - the strace order.
  Every finding is in the gate or the documents.

  Findings:
  - **L2:** as root the gate is red on a correct seed. The README says 7; the row always expects 3 (measured under
    `unshare -r`). MACHINE does not state the non-root requirement.
  - **L2:** the header restates the contract (the seventh report).
  - **L2:** rule 5 misses an `Exit status: 0 1 2 9` heading line and a `status N:`-form block.
  - **L2:** rule 9 is case-sensitive ("Excursus 001" is green).
  - **L2:** rule 3 passes a target holding only `syscalls.tsv`.
  - **L2:** the status mutant accepts any kind; R31 claimed it fixed.
  - **L2:** R27's exit codes do not hold (tracebacks give rc 1).
  - **L2:** R27/R28's "every step is guarded" does not hold, and failures are misattributed.
  - **L2:** the per-target design is not what the gate does. DESIGN:41-45's "checks every target's bytes … no
    execution" dies for any non-x86 architecture. The fuzz hard-codes x86 opcodes, and verify writes 537.
  - **L2:** EXPECTATIONS and the output do not line up. The SIGXFSZ checks print as "row 6", and there are no rows for
    the refusals, the trunc mutant, the clone rows or driver-test.
  - **L2:** LAYOUT:18 omits RECOVERY.
  - **L3 (not counted):**
    - row 8 ignores syscall order;
    - "no core" beside "dumped core";
    - rule 2 reads byte-0 magic only;
    - stale `out/`;
    - the stated fuzz basis against `DUR_LONG`;
    - the fuzz's unscaled `timeout=5`;
    - 7-before-3 for fstat OUT.
  - It withdrew the RECOVERY green-line finding, already fixed.
- **temperare: 0 L1, 3 L2.** A full verify takes 38.2 s:

  | step | time |
  |---|---|
  | layout-mutants (45 layout runs) | 14.4 s |
  | contract | 10.5 s |
  | driver-test | 9.5 s |
  | clone rows | 2.9 s |

  The candidate copies and clones are cheap, and they buy R34's proof. The seed's byte-at-a-time I/O is confirmed
  exempt. The second vigilia's temperare L1 and L2 are fixed for the content scans and for stopping early.
  - **L2:** R30's "list fetched once" does not hold. The visible list is fetched three times per run, and the name
    loops fork `basename`, `grep` and `mktemp` per entry (127 execs per run). A tempered copy using builtins took
    layout-mutants from 17.3 to 12.3 s, still green.
  - **L2:** the status self-test's first possible disagreement is case 1043, because the 1024-case sweep runs before
    `NEAR`. Putting the boundary cases first: 3.02 to 0.16 s, the main fuzz still 2000 agree.
  - **L2:** the three hang proofs run one identical stub (6.5 s), proving gate-lib's timer three times (as
    complectens and vocare found).
  - **L3 (not counted):**
    - the nested non-host run repeats the clone section;
    - rule 7's seven `grep -R` runs;
    - rule 2 reads about 7 MB per run;
    - the stale timing basis in gate-lib;
    - systemd-coredump still starts on every run;
    - the layout re-run after the mutants.
- **struere: 2 L1, 11 L2.** The seed is clean after O_NONBLOCK:
  - all 33 branches recomputed by hand, each landing on its commented target;
  - 537 bytes, equal to `p_filesz`;
  - 0x841 and the stat offsets;
  - every register lifetime holds.
  Its own probes left two crash entries in the journal.

  Findings:
  - **L1:** fuzz says it kept the failing input, then deletes it. On a hang, its own `finally` removes it; on a
    disagreement, verify's trap removes it (measured through a full verify). R28 and R29 fail.
  - **L1:** a Python crash is reported as a check failure in disasm-check, syscalls-check and fuzz. When layout's
    rule-2 scanner raises, it prints an empty `rule 2:`. R27 fails.
  - **L2:** an interrupt leaves the running step alive after the verdict. `set -m` puts each step in its own group;
    on SIGINT or SIGTERM the driver dies and reap_group never runs. Measured: the step wrote a file 4 s after the
    verdict. R28's "owns its processes" fails. Trap INT and TERM, and kill `-$pid`.
  - **L2:** fault.c's ptrace path (NTH ≥ 2) resumes every signal with 0. SIGTERM is swallowed, and a SEGV re-faults
    forever until the timer kills it, so a crashing seed would be reported as "timed out". Re-inject `WSTOPSIG`.
  - **L2:** `timed_out` decides from the rc alone (as mora and conformare found).
  - **L2:** fault.c narrows `long` to `int` unchecked. NTH 2^32+1 becomes 1, NR 2^32 becomes `read`. Range-check,
    then exit 93.
  - **L2:** fault.c's "every fd from 3 up is closed" is false at NOFILE 524288 (fd 300 survives). Use `close_range`.
  - **L2:** layout.sh's temp directory is a fixed `$HEX0_SCRATCH/layout-tmp`. It is adopted and then deleted (a
    pre-existing `keep.txt` vanished), and two runs sharing a scratch directory went red 5 times in 6 trials, each
    with the wrong cause. Use `mktemp -d`.
  - **L2:** the time knob: 0 removes all limits, "08" is an octal error, and fuzz's `timeout=5` is unscaled.
  - **L2:** the status mutant accepts any kind.
  - **L2:** seven Python steps and two `cp -a` run unguarded; the trunc mutant's exit is never checked.
  - **L2:** the register table hides rsi's four values (the stat buffer, 0x1ED, 0, then the byte buffer). Trusting
    it, a reader would judge `+0153 mov %rsp,%rsi` redundant. List each register's values in order, with offsets.
  - **L2:** the header restates the contract (the eighth report).
  - **L3 (not counted):**
    - the FIFO-reader row cannot tell ENXIO from S_ISREG;
    - "no core" cannot fail;
    - seccomp has no arch check and compares only the low 32 bits;
    - the dead `ALLOWED`;
    - a README restore taken from HEAD;
    - the knobs are undocumented;
    - reap_group silently kills leaks;
    - the fact lookups have no presence check.
- **sequi: 3 L1, 8 L2.** The seed's register thread holds on every path, traced by hand:
  - each exit path is balanced;
  - rsi carries 0x841, rsp, 0x1ed, 0 and rsp again;
  - rdx is 1 through the loop;
  - r14b, r15b and r10b behave as documented;
  - the order is 7, then S_ISREG, then fchmod, then ftruncate.

  Findings:
  - **L1:** the gate inherits git's environment. Nothing unsets `GIT_DIR`, `GIT_INDEX_FILE` or `GIT_WORK_TREE`, and git
    exports those to hooks, which is the natural place to run verify before a checkpoint.
    - Measured on a copy: `GIT_INDEX_FILE=<repo>/.git/index tools/verify.sh` rewrote that repo's index and staged a
      reverted `.gitattributes`.
    - `GIT_DIR=<repo>/.git` created a "hex0 gate candidate" commit on that repo's branch, with stubbed modules.
    - The live repository was not touched: I checked that no such commit exists anywhere in it.
    - R34's "the live index is never touched" fails. Unset `GIT_*` on entry, in the driver and in every module.
  - **L1:** fuzz deletes the hung input (the sixth report).
  - **L1:** under the gate, "kept <path>" for a disagreement is deleted by the trap (as struere and conformare found).
  - **L2:** steps without a timer. The seed replaced by a FIFO hung seed-audit's `cmp` at :59 with no bound.
    driver-test's header overclaims.
  - **L2:** `HEX0_TIME_SCALE`:
    - 0 disables the timers, and `HEX0_TIME_SCALE=0 driver-test.sh` hung, orphaning a `timeout … 0 cat`;
    - leading zeros are read as octal;
    - the die inside `$(…)` gives rc 125.
  - **L2:** Ctrl-C does not stop the running step (as struere found).
  - **L2:** the durations are not written once: fuzz's `timeout=5` and the contract's `sleep 30`.
  - **L2:** relative arguments resolve from the repo root, after the `cd`:
    - seed-audit with sandbox `sa` left `?? sa/` in the repo;
    - hex0-contract with `hc2` ran its rows in the repo and then failed with the wrong cause;
    - `HEX0_SCRATCH=.` makes layout.sh red on its own temp directory.
  - **L2:** the environment knobs are not declared anywhere a user looks. `HEX0_SANDBOX=/var/tmp/../…` escapes the
    guard. The second vigilia's sequi L2 was never addressed.
  - **L2:** the exit codes do not match their documentation (R27).
  - **L2:** syscalls-check's `global ALLOWED`.
  - **L3 (not counted):**
    - the register tables omit the loop roles;
    - `out/` is shared and stale;
    - `fix_ok`'s global;
    - fault.c swallows signals;
    - the plain clone inherits a global `core.autocrlf`;
    - rule 7 scans ignored files.
- **peragrare: 4 L1, 8 L2.** Census scripts are in `/var/tmp/vigilia3-hex0/peragrare/census/`. Of the second vigilia's
  32 unvisited cells, 30 now hold. The two that do not are row 1 and the 3a mutant. The main fuzz grid has no empty
  cell, and the contract grid has none filed.
  - **L1:** a linked worktree breaks the candidate rows. `cp -a .` copies a `.git` FILE that points at the live
    gitdir, so the candidate's add, config and commit act on the live repository.
    - Measured in a worktree of its copy: rc 0, the copy's branch gained 4 commits (driver-test's stubbed candidate
      and two "without the attribute line"), HEAD lost `* text=auto eol=lf`, and `commit.gpgsign` was written to the
      shared config.
    - Our repository has no worktree, no such config and no such commits: checked.
    - Distinct from sequi's `GIT_*` finding. Fix: the candidate is built with `git init` plus a copy of the files, or
      `git clone` of a temporary index; it never carries the original `.git`.
  - **L1:** the clone rows read one file. The eol check reads only `crlf-clone/tools/verify.sh`, and both rows run the
    LIVE layout.sh against the clone, never the clone's own gate. With `tools/check/*.sh text eol=crlf` added, verify
    printed "autocrlf clone: lf" and rc 0, while the clone's seed-audit had 163 CRs and dies with `bash\r`. The fix:
    check every text file for CRs, or run the clone's own `layout.sh`.
  - **L1:** the row-1 mutant (the fifth report). Measured: rows 1, 2 and 10 all made inert with `--size 999`, and
    seed-audit is still green.
  - **L1:** fuzz loses both the hung input and the disagreement (the seventh report).
  - **L2:** row 2 (the stranger's decode) is never shown red.
  - **L2:** row 10 is never shown red.
  - **L2:** the status self-test is hollow (it accepts kind 5).
  - **L2:** the 3a mutant is hollow. `note.md` is caught by the note-name check, so deleting the `*.md` branch stays
    green, and `plan.md` passes.
  - **L2:** rule 7 misses quoted paths: `> "out/nope"`, `>'out/nope'`, `of="out/nope"`, `-o "out/nope"` and
    `>"$ROOT/out/nope"` are all green.
  - **L2:** a rule-2 scanner exception (a 0xFF filename) is reported as an empty rule-2 violation.
  - **L2:** a hang in any unguarded step is unbounded and invisible to the hang proofs.
  - **L2:** R28's "no descendant alive" is unproven, and a `setsid` child escaped.
  - **L3 (not counted):**
    - as root, the read-only row goes falsely red;
    - the FIFO-reader race was not observed in 200 runs;
    - the CRLF fixtures still pass after the CRs are stripped;
    - seed-audit dies for any non-x86 target;
    - rule 3 accepts a lone `gate.tsv`.

All 19 inward wards are in. circumspicere is cast last.
- **circumspicere (cast last): 1 L1, 5 L2.** These surroundings hold:
  - a path with a space and brackets;
  - an inherited fd 3;
  - real argc 0 on kernels before 5.18;
  - an ASCII source;
  - no leaked sandboxes.

  Findings:
  - **L1:** the gate runs the user's git hooks. `cp -a .` copies `.git/hooks`, and the candidate's commits run them.
    - Measured: a pre-commit hook of `exec tools/verify.sh` is red, with the wrong cause. A marker hook ran 3 times
      per verify, and a global `core.hooksPath` hook ran too. A policy hook (`exit 1`) turns a correct tree red.
    - This breaks LAYOUT's "depends on nothing outside the repository", and it blocks the obvious enforcement (verify
      as a pre-commit hook).
    - It is distinct from sequi's leak in the other direction. Closure: hooks off, global and system config off, and
      `--template=` on clone, for every sandbox git call.
  - **L2:** a fresh machine with no git identity is red (`unable to auto-detect email address`). **This corrects my
    R34 weigh,** which withdrew the concern: my probe emptied HOME, but `XDG_CONFIG_HOME` still supplied the
    identity. Closure: a fixed `-c user.name/user.email` in the sandbox.
  - **L2:** row 9 cannot parse an instruction longer than 7 bytes. objdump splits a `movabs imm64` across two lines,
    giving a phantom empty instruction. The seed passes only because its longest instruction is exactly 7 bytes;
    hex1 will exceed that. Closure: `--insn-width=15`.
  - **L2:** nothing sequences the ladder except the bash gate. DESIGN claims "not given: … no compiler from
    elsewhere", but no build entry point exists, and LAYOUT forbids `tools/` from building. stage0-posix closes this
    with a seed-built shell (kaem). DESIGN must say what sequences the rungs before hex1's brief. This is a design
    question for the builder.
  - **L2:** the GitHub page:
    - "bootstrapped" is present tense, while the README says "not landed";
    - the languages bar shows C (`fault.c`), and the gate links three C programs against glibc, against "no C";
    - the homepage is the superseded era's site.
    The builder's call.
  - **L2:** README presents RECOVERY as a stranger-facing doc, but it is an agent-session map (datamancy, `~/Work/holon`
    paths, pulsare).
  - **L3 (not counted):**
    - the ASCII invariant is unasserted: a Latin-1 comment byte makes `sed|xxd` locale-dependent;
    - row 9 matches binutils 2.47's spelling exactly;
    - accretion: WEIGH is 112 KB and SCORE 40 KB for 537 bytes, one finding was counted 8 times, and `brand/` is
      6.2 MB;
    - an aarch64 host is red by design;
    - fsmonitor daemons.

### The third vigilia's verdict — DIVERGES

The seed has converged:
- no ward found a defect in its bytes or behaviour;
- experiri drove 62 cells, all discriminated;
- every branch and register was traced by hand twice;
- the remaining seed work is its header (a restated contract) and its register table.

The gate has not. Several round-5 claims do not hold (R25, R27, R28, R29, R31), and the new round-5 surface carries
the new L1s (git environment, worktrees, hooks, clone rows). The builder ruled on 2026-10-04: L2s may be runed with
reasons, and tooling comes first, until it is sufficient. Round 6 is drawn as consolidation, not as line items.

## Round 6 — consolidation: remove the classes, prove every row, rune the rest (2026-10-04)

The builder, 2026-10-04: *"what's important to me here is that we have strong guardrails before we begin serious
work"*, and *"L2 can be runed with reasons"*.

The seed's behaviour is done; the only seed edits are to comments. Every item below removes a CLASS, not an instance.
Each names the wards behind it; the third-vigilia entries above hold every finding in full. **Each item's proof is a
mutant that breaks the thing and goes red.** My weigh will break each one myself.

- **R35 — the seed header is a pointer, and the README says exactly what holds** (probare, solvere, vocare, cernere,
  excusare, conferre, struere, nesciens, experiri, cohaerere).
  - `hex0.hex0` keeps what the bytes need: registers, offsets, syscalls, the ELF layout and the trust phrase. It
    points to the README for the input language and the statuses, and restates neither.
  - The register table lists each register's values in order, with the offset that sets each one (rsi holds four).
  - Fix the headings: `keep IN's st_dev and st_ino`, `read setup`, `comment start`.
  - The README moves its x86 facts (registers, the 144-byte stat, offsets) into the target header.
  - **README wording:**
    - the order: a failed open/fstat of OUT is 3, then same file is 7, then not regular is 3;
    - the same-file read-only case is 3 unless the open succeeds, which needs CAP_DAC_OVERRIDE effective over that
      inode on a writable mount;
    - SIGXFSZ is shell status 153;
    - "total" carries DESIGN's bound (a signal or a block is not a status);
    - opening a device can have driver side effects, with the O_NOCTTY clause removed.
  - The README gives the stranger a disassembly line:
    `objdump -D -b binary -m i386:x86-64 --start-address=0x78 hex0`.
  - BRIEF:31 and :70 stop asking for a second copy of the table.
  - **Proof:** layout goes red on a target source that states any status meaning. The rule reads `status N` and any
    line under `Exit status:`, so a rule-5 mutant for each form excusare showed green.
  - **Proof:** a lint row that the source is ASCII.
- **R36 — one step primitive, and no command outside it** (conformare, mora, struere, sequi, complectens, purgare,
  peragrare, conferre).
  - gate-lib has two helpers, and only two: `step LABEL SECS -- cmd`, which must succeed, and
    `expect LABEL SECS WANT -- cmd`, which must give that status or text.
    - Both capture output, replay it with the label on failure, and print got and want.
    - Both decide "timed out" from timeout's own `sending signal KILL` line, never from the rc.
  - Every command in every module and in the driver goes through one of them. That includes the heredoc pythons,
    `cp`, git, `cmp`, `stat`, the FIFO reader and the mutant generators, with their "found nothing" exits read.
  - **Proof:** a lint row that goes red on a bare command in a module, with a mutant.
  - **Time:**
    - `HEX0_TIME_SCALE` must match `^[1-9][0-9]*$`, validated once at source time;
    - fuzz takes its per-case limit from gate-lib;
    - the FIFO reader opens with `exec 3<>fifo` before the row;
    - the stated basis matches a measurement.
  - **Interrupt:** INT and TERM kill every live step group before exit.
  - **Proof:** a hang stub that kills itself (`kill -KILL $$`) is NOT "timed out". A step with a `setsid` child
    reports the escape. After Ctrl-C, no step is alive.
  - fault.c re-injects signals on the ptrace path, range-checks its arguments before narrowing them (93), and uses
    `close_range`.
- **R37 — the gate cannot touch any repository but its own sandbox** (sequi, peragrare, circumspicere).
  - Every git call goes through one function. It unsets `GIT_*` and sets:
    - `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`;
    - `-c core.hooksPath=/dev/null` and `--no-verify`;
    - a fixed `user.name`/`user.email`;
    - `commit.gpgsign=false` and `core.fsmonitor=false`;
    - `--template=` on clone.
  - The candidate is built with `git init` plus a copy of the visible files, never a `cp -a` of `.git`.
  - The clone rows run the clone's OWN `tools/layout.sh`, and check every text file for CR.
  - **Proof:** the gate is green, and the outer repository is byte-identical (HEAD, index, config, refs) when it
    runs:
    - in a linked worktree;
    - with `GIT_DIR` and `GIT_INDEX_FILE` set;
    - with a failing pre-commit hook and a global hooksPath;
    - with no git identity.
  - **Proof:** `tools/check/*.sh text eol=crlf` added to `.gitattributes` is red.
- **R38 — per-target facts live only in `gate.tsv`, and a target is a machine in hand** (solvere, purgare, excusare,
  conferre, circumspicere).
  - `gate.tsv` holds the size, the objdump machine, `--insn-width=15`, `code_base`, the row-9 mutant text, and the
    fuzz bound and letter patterns.
  - Modules take the target DIRECTORY, as one calling convention, and every fact read is checked for presence.
  - `verify.sh` passes no per-target values.
  - A target directory not named in DESIGN's Targets table is red, and DESIGN's table is the list layout reads. This
    removes the name-keyed skip class: the `x86_64-freebsd` seed cannot be "not executed".
  - Relative arguments are refused; modules take absolute paths.
  - The gate refuses to run as root, with a message naming why, and MACHINE says so.
- **R39 — every row is a function, and every mutant calls it** (complectens, intueri, vocare, peragrare, purgare,
  temperare).
  - Each comparison is a named function. Its mutant calls that same function on broken input and requires that
    function's own refusal text.
  - Delete `row1-diff.py`.
  - Mutants are added or rebuilt for these rows, each failing for its own reason:
    - rows 1, 2 and 10;
    - contract rows 3 and 4;
    - the clone rows;
    - the status self-test, which requires kind 3;
    - rule 3a (a target `plan.md`);
    - rule 7's quoted forms;
    - a tools write into `ladder/*/*/hex0`.
  - Driver: one hang proof. "No module can hang" is carried by R36's lint, not by three identical stubs.
  - The fuzz forces its boundary cases first.
  - Delete the post-mutant re-checks that cannot fail.
- **R40 — failure evidence survives the failure** (mora, conformare, struere, sequi, peragrare, cernere).
  - The fuzz prints the input bytes in its message, for a hang and for every disagreement kind; it keeps no files.
  - Every Python check has one wrapper: an unexpected exception exits 99. Each header lists its codes.
  - layout's rule-2 scanner reports a crash as a crash.
  - The "no core" row asserts what it can observe (rc 153 and RLIMIT_CORE 0), labelled honestly.
  - It does not grep bash's localized note: pin `LC_ALL=C` or assert the rc only.
- **R41 — layout's exemptions are no wider than their reasons** (excusare, conferre, peragrare, struere, temperare).
  - `brand/`: image magic (PNG, ICO, SVG) and no ELF magic anywhere in the file.
  - Hidden names are examined, not skipped.
  - `tests/` is not exempt from the process-document checks.
  - Rule 3: a target's source is the rung's source name, not "any file but hex0".
  - Rule 9 is case-insensitive.
  - Rule 7 also catches quoted and variable `out/` paths.
  - The gate empties `out/` at the start of each run (it owns `out/`).
  - layout's temp directory comes from `mktemp -d`.
  - Each rule scans with builtins over one list fetched once.
  - `HEX0_DRIVER_TEST` is honoured only together with the marker the parent driver-test sets.
- **R42 — the documents agree with the tree** (cohaerere, exigere, intueri, conferre, circumspicere).
  - **LAYOUT:**
    - each rule states its real scope ("every name on disk" or "every file not git-ignored");
    - the standing list names RECOVERY;
    - rule 7's wording;
    - "There is no CI.";
    - watc has one home.
  - **WARDS:** describe the casting in use (the agent fetches its own signed text).
  - **EXPECTATIONS:** "amended through round 6; see WEIGH", and a row for every check the gate prints. SIGXFSZ, the
    refusals, the clone rows and driver-test get their own row numbers; no row label is reused.
  - **BRIEF:45:** `hex-check.py` is "a second reader".
  - **"The one binary not built from source"** becomes "one per target: that target's seed", everywhere.
  - **MACHINE:**
    - split "the gate runs these" from measurement tools bound to a named rung;
    - list gcc's real use;
    - the gate needs: a non-root user, a git working tree (not "a worktree"), exec on `/var/tmp`,
      `ptrace_scope` ≤ 1;
    - the knobs (`HEX0_SANDBOX`, `HEX0_TIME_SCALE`).
  - **DESIGN:** the TSV column order, and the alignment check bound to hex1's EXPECTATIONS.
  - **`.gitattributes`:** the CR comment.
  - **README:** link RECOVERY as "the agent-session recovery map", not as how to restore the tree.
- **R43 — a wall for every paid-for failure** (curare; the builder's "sufficient").
  - Add a table to this excursus with one row per failure mode in RECOVERY's list and per class above. Each row
    names the check that goes red, and the mutant that proves it.
  - A row with no wall is open work, shown as such.
- **R44 — every remaining L2 is fixed or runed.**
  - For each third-vigilia L2 not closed by R35–R43, either fix it, or add
    `rune:<ward>(<category>) — <reason>` at the site.
  - SCORE lists every L2 with its disposition: fixed, runed (with the rune's line), or covered by R-n.

**Not in this round. These are open for the builder:**
- what sequences the rungs (circumspicere C3-4), needed before hex1's brief;
- the GitHub description and homepage (C3-5).

After round 6: my re-run, breaking every row through its own function, then a checkpoint, then vigilia 4.

## Round 6 received — weighed by breaking every row (2026-10-04)

**Live:** `tools/verify.sh` rc 0, with empty stderr. `git status` and every file under `.git` (sha256 of the contents)
are identical before and after. Grok's note that a tar of `.git` hashed differently is file metadata (mtimes), not
content.

**The break battery** (`/var/tmp/r6-weigh/battery.sh`). Each case ran in its own copy. A named row function was made
to `return 0` first thing, so a mutant that really calls its row must then stay green and kill the gate.

| broken | verify | the gate said |
|---|---|---|
| `row1_same` | red | `mutant row 1 (byte) stayed green` |
| `row2_same` | red | `mutant row 2 (byte) stayed green` |
| `row9_check` | red | `mutant row 9 (comment) stayed green` |
| `row10_check` | red | `mutant row 10 (size) stayed green` |
| `row11_lint` | red | `row 11 text` |
| `row3_same` | red | `mutant row 3 (bytes) stayed green` |
| `row4_status` | red | `mutant row 4 (status) stayed green` |
| `row8_check` | red | `mutant row 8 (extra syscall) stayed green` |
| `cr_check` | red | `plain clone` |
| `row4_bytes` | **GREEN** | no mutant calls it |
| `fix_ok` (row 6: all 21 format fixtures) | **GREEN** | no mutant calls it |
| `assert_out` (what OUT holds, on every refusal and fault row) | **GREEN** | no mutant calls it; the trunc mutant uses its own assertions |
| `clone_layout` | **GREEN** | no mutant calls it; the SCORE's "both clone rows' layout" is false |
| header states `status 4: …` | red | `rule 5: target source states a status meaning` |
| bare `cmp` in seed-audit | red | `step-lint … bare command: cmp line 34` |
| "timed out" decided by rc 137 | **GREEN** | the self-kill proof is hollow: `carry`'s wrapper bash prints `rc:137` and exits 0, so the step's rc never reaches the timer decision. The shipped code (it greps timeout's `sending signal KILL`) is right but unproven. |
| `HEX0_TIME_SCALE=0` | refused | `must match ^[1-9][0-9]*$` |
| `GIT_DIR`, `GIT_INDEX_FILE`, `GIT_WORK_TREE` pointed at a victim copy | green | victim `.git` byte-identical |
| failing pre-commit hook in `.git/hooks` | green | |
| `env -i`, empty HOME and XDG, no system config (no identity) | green | |

**Verdict:** round 6 holds for every class except one. **A comparison with no mutant that calls it** survives in four
row functions, and one proof is hollow. These are the same class as the fake row-1 mutant, now found by mechanism,
not by a ward. Checkpointed. R45 removes the class.

## R45 — every named comparison is proven by mechanism, not by hand (2026-10-04)

The class is "a named comparison no mutant exercises". Hand-written mutants keep missing rows: row 1 last round, and
four rows plus one proof this round. Remove the class by construction:

- **A gate module, `tools/check/row-proof.sh`,** run from `verify.sh`. For every row function the modules define
  (step-lint already parses them), it makes a sandbox copy of the gate in which that one function's body is
  `return 0`. It then runs only the module that owns the function, and requires the module to go red.
  - A function exempt from this needs a `rune:complectens(<category>) — <reason>` at its definition. A helper that
    is not a comparison is such a case.
  - Every other row function must go red under this proof.
  - This is the battery above, made a row.
- **The four missing mutants come for free from that module:** `row4_bytes`, `fix_ok`, `assert_out` and
  `clone_layout`. Each must go red under it. `clone_layout` lives in `verify.sh`, so the module must cover the
  driver's own row functions too.
- **The self-kill proof** runs through `step`/`expect` directly, with no `carry` wrapper in the way. Prove the
  reason: in a gate copy with the timer decision changed to `rc == 137`, the proof goes red.
- **Proof of the module itself:** a row function added without a rune, whose mutant never goes red, makes
  `row-proof` red.

After R45: my re-run, the battery again (now the gate's own row), a checkpoint, then vigilia 4.

## R45 received — weighed (2026-10-04)

- **Live:** `tools/verify.sh` rc 0 in **1,754 s**, with empty stderr. Every file under `.git` (sha256 of the
  contents) and `git status` are identical before and after.
- **Breaking it:** in a copy with `row4_bytes` forced to `return 0`, `row-proof.sh` went red with
  `verify: row 4 bytes did not compare`. Each row now records that it compared (`row_did`), and the caller dies when
  the record is missing. That is a second wall under row-proof's own.
- **The SCORE's other proofs:**
  - every row function is red under row-proof, including the four the battery left green and `clone_layout`;
  - the self-kill proof is an `expect 137`, and it is shown red against a `rc == 137` timer decision;
  - an unruned function that stays green makes row-proof red;
  - the four exempt helpers carry `rune:complectens(helper)`.
- **The cost:** row-proof re-runs a whole module per function, and the driver-level functions re-run `verify.sh`. The
  gate went from about 40 s to about 30 min. That works against the builder's aim, guardrails for faster iteration.

Checkpointed. R46 splits the tiers.

## R46 — two tiers, and the gate always says which ran (2026-10-04)

- **`tools/verify.sh`** runs everything except row-proof. Its final line names the skip: `verify: … row-proof not
  run`. It is for every edit and every executor strike.
- **`tools/verify.sh --prove`** runs the same, plus row-proof. Its final line says `proved`. It is required before
  every checkpoint, landing and vigilia; my weigh runs it.
- No environment variable selects the tier. The flag is the only switch, and an unknown argument is refused.
- **Proof:**
  - the fast tier's final line names the skip, and the fast tier finishes in under 2 minutes on this laptop
    (measured and recorded in SCORE);
  - `--prove` with one row function forced to `return 0` is red;
  - the fast tier with the same break is red too, through `row_did`, or the SCORE says why not;
  - an unknown argument is refused.
- **Documents:** LAYOUT, RECOVERY ("Green is …") and EXPECTATIONS name both tiers, and say which one each checkpoint
  requires.

## R46 received — the tiers hold, and the fast tier is slow (2026-10-04)

- **Live fast tier:** rc 0, empty stderr, and `.git` byte-identical. The last line names the skip. An unknown argument
  is refused. Grok's break of `row4_bytes` is red in both tiers (`row 4 bytes did not compare`).
- **Too slow:** the fast tier took **495 s** on my run and 522 s on Grok's. R46's own criterion was under 2 minutes, so
  it fails, and Grok's SCORE says so.
- **Where the time goes** (each output line timestamped):

  | module | now | at `9b334d1` |
  |---|---|---|
  | layout-mutants | 263 s | 14 s |
  | contract | 125 s | 10 s |
  | driver-test | 67 s | 10 s |

  One `layout.sh` run takes 6.1 s against 0.41 s at `9b334d1`, with about 3,900 execs per run.
- **The cause, measured:** one `step` call costs **301 ms**, of which **282 ms** is `_marks_alive`, the setsid-escape
  scan. For every one of the ~431 `/proc/*/environ` files it forks a `tr` and a `grep`. R36 routed every command
  through `step`, so that cost is paid thousands of times. R36's wording ("every command … goes through one of
  them") was mine; the per-call cost was never measured when it was drawn.

Checkpointed. R47 makes the step cheap.

## R47 — a step costs milliseconds, and the fast tier fits its budget (2026-10-04)

- **The escape scan.** `_marks_alive` reads every environ in ONE process: `grep -l -z -x -F "HEX0_STEP_MARK=$mark"`
  over `/proc/[0-9]*/environ`, with unreadable files skipped and the pids taken from the paths. No fork per process.
  Keep the existing proof: `driver: setsid escape` must still go red when a step leaks a setsid child.
- **Measure, then decide granularity.** Record the per-`step` overhead (the mean over 20 calls of `step … -- true`)
  and one `layout.sh` run in SCORE.
  - If the fast tier is still over 2 minutes, make `layout.sh` a single step from its callers, not a `step` per
    internal command. Its children only read local files, the caller's timer bounds the whole run, and its own
    `layout: rule N:` lines label every failure.
  - In that case, exempt `layout.sh` from step-lint with `rune:mora(bounded-by-caller)` and that reason.
- **Proof:**
  - the fast tier's measured time is in SCORE and is under 2 minutes on this laptop;
  - `--prove` still goes red with one row function forced to `return 0`;
  - the setsid-escape proof is still red-proven.

## R47 received — weighed (2026-10-04)

- **Fast tier, live:** rc 0 in **98 s**, empty stderr, and `.git` byte-identical. The last line names the skip.
- **`--prove`, live:** rc 0 in **299 s** (it was about 30 min at R45). Empty stderr, and `.git` byte-identical. 24 row
  functions are red under row-proof, and the last line says `proved`.
- **The step:** 30 ms per call (Grok's mean over 20 calls), down from 301 ms. The escape scan is one `grep -z` over
  `/proc`, and a pid must still carry the mark on a second read.
- **The escape scan earned its keep.** The cheaper scan found that sandbox `git commit` was starting a detached
  `git maintenance run --auto`, which carried the step mark and outlived its step. That is a real escape, closed with
  `maintenance.auto=false` in `git-sandbox`. After my runs, `ps` lists no `git maintenance` process.
- **A slip of my own:** my first leftover check used `pgrep -f`, which counts its own shell (a standing rule says
  never). I re-checked with a `ps` listing.

Checkpointed. Next: vigilia 4, against this checkpoint.

## The fourth vigilia (2026-10-04) — in flight

Cast at checkpoint `8201e8d`, after round 6, R45, R46 and R47. The same 19 inward wards, each fetching its full signed
text. CONVERGENCE means zero L1 and no un-runed L2. A rune counts only if its reason earns it, and the wards judge
each rune's reason. circumspicere is cast last.
- **nesciens: 0 L1, 2 L2.** The cold walk holds:
  - the `sed|xxd|cmp` line gives `cmp=0`;
  - the objdump line, run from inside `x86_64-linux/`, matches all 156 comments;
  - the ELF fields check out by hand;
  - every fixture, and the fixpoint, behave as the README says;
  - links resolve;
  - the fast tier is green.

  Findings:
  - **L2:** R35 does not fully hold. `hex0.hex0:18-19` still says "objdump is given --adjust-vma so its addresses are
    file offsets", four lines after the one-liner, which needs no such flag. Adding it labels the ELF header as code.
    Delete the clause, or name seed-audit's own recipe.
  - **L2:** the README's objdump line uses a bare `hex0`, but README:5 places the reader at the repository root,
    where it fails (`No such file`). No row runs this line. Use `ladder/0-hex0/x86_64-linux/hex0`, as the sed line
    does, and do the same in the header.
  - **L3 (not counted):**
    - terms used before they are defined (rung, watc, weigh);
    - "one per target: that target's seed" lost its antecedent ("the one binary not built from source");
    - "`objdump -d` prints nothing" is not exact;
    - the expected results live only in the contract script;
    - README:24's capability sentence is opaque;
    - "the three ways out of the loop".
- **cohaerere: 0 L1, 7 L2 (INCOHERENT).** These hold:
  - WARDS' casting procedure;
  - RECOVERY's green line;
  - "total" bounded;
  - "one per target";
  - the exit table matching BRIEF;
  - the rule-5 pointer.

  Findings:
  - **L2:** who decoded the seed. LAYOUT:44-47 says `hex-check.py` decoded it ONCE, and builds rule 7's `tools/`
    exception on that. BRIEF:43, the README, the header, DESIGN and MACHINE say `sed|xxd` decoded it and `hex-check.py`
    is "a second reader". The third vigilia's L2 is not closed. Settle one provenance.
  - **L2:** layout scope. Rules 6 and 8 say "tracked", but the gate examines untracked files (shown red on an
    untracked colon file and an untracked archived file). Rules 2, 3, 4 and 9 state no scope in LAYOUT. R42 does
    not hold.
  - **L2:** DESIGN's Targets table lists `aarch64-linux` and `riscv64-linux` as "not a target until a machine is in
    hand", yet layout reads every name in it as admitted. An `aarch64-linux` target with no machine is green and
    "not executed". R38's class is not removed.
  - **L2:** the header's `--adjust-vma` sentence (as nesciens found).
  - **L2:** the rung README still holds x86 facts: the usage line says "on x86-64 Linux", plus the objdump recipe and
    the 144-byte stat slot. R35 does not hold.
  - **L2:** RECOVERY and CRAWL called Q1–Q5 open after they were ruled. These are my files. **Fixed in the commit
    that records this entry:** CRAWL marks them ruled, and RECOVERY names the open dilemmas, the sequencer and the
    GitHub items.
  - **L2:** EXPECTATIONS has no rows for:
    - the git isolation lines;
    - "outer repository unchanged";
    - the driver proofs (setsid escape, scale refusal, interrupt, replay, non-host);
    - "second target with a pointer";
    - row-proof itself.
    R42 does not hold.
  - **L3 (not counted):**
    - DESIGN's TSV column order is still wrong;
    - `.gitignore:3`;
    - LAYOUT:33's rule-2 scope;
    - BRIEF:33 lacks the capability qualifier;
    - "proved" sits beside "proves self-consistency";
    - 0755 against umask before fchmod;
    - MACHINE's list of gcc uses;
    - no wards were cast at the R45–R47 weighs (vigilia 4 covers them);
    - 255 s for the fast tier under load.
