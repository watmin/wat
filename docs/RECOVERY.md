# RECOVERY — read this first after a gap

**This file is a MAP, not the truth.** The truth is the git log, the excursus documents, and the code. Every line
below names where to read; none of it is meant to be enough on its own. If this file ever starts to feel like enough
orientation, prune it.

## The gathering (run it; don't narrate it)

1. Fetch `recolligere` from the datamancy signed channel (`fetch_spell`), and the grimoire first.
2. Check the **freshness probe** below against the disk:
   `git -C ~/Work/holon/wat log --oneline -1` and `git -C ~/Work/holon/wat status --short`. A mismatch means trust
   the log, not this file.
3. Read **NOW** below, then the newest sections of the live excursus's WEIGH, then its SCORE.
4. Only then answer or act.

## The workspace

- **`~/Work/holon/wat`** (watmin/wat): the native, Rust-free wat. This repository. **Grok's territory**: Grok strikes
  here, and the orchestrator weighs and commits.
- **`~/Work/holon/the-little-wat`**: watc, the self-hosting compiler; it "stays where it is" as reference material.
  It has its own breadcrumb: `NEXT.md`.
- **`~/Work/holon/wat-rs`**: the Rust interpreter, branch `the-little-wat`. Paused for native work.
- **`~/Work/holon/scratch`**: the builder's design notes. Read it; do not edit `random-notes.txt`.
- **Never run git in `~/Work/holon/` itself. Never use worktrees.** `/tmp` is a tmpfs, so long-lived scratch goes
  under `/var/tmp`.

## Where the truth lives

- `docs/LAYOUT.md`: where everything goes, enforced by `tools/layout.sh` (a red gate on any violation).
- `docs/WARDS.md`: which datamancy wards are cast at each weigh.
- `docs/MACHINE.md`: the tools a fresh box needs.
- `docs/excursus/YYYY/MM/NNN-<slug>/`: each piece of work. Its DESIGN, CRAWL, BRIEF and EXPECTATIONS are what was
  drawn; SCORE is what the executor reports; WEIGH is the orchestrator's verdict, round by round, and its newest
  section is the current state.
- `tools/verify.sh`: the gate, in two tiers. The fast tier takes no argument and is for every edit and every executor
  strike. Green on that tier is rc 0 and a last line that names the skip: `verify: sandbox candidate, clone layout,
  outer repository unchanged, row-proof not run`. `tools/verify.sh --prove` is the same gate plus row-proof. Green on
  that tier is rc 0 and a last line that says `proved`. A checkpoint, a landing, and vigilia require `--prove`. The
  flag is the only switch. An unknown argument is refused. Anything else is red.

## NOW (replace this section; never append to it)

- **Freshness probe:** written at the commit that adds this line (after `74b8f03`). The tree may hold uncommitted strike files only while Grok is mid-round.
- **Live excursus:** `docs/excursus/2026/10/001-the-ladder/`, rung 0, hex0. It is the 537-byte seed at
  `ladder/0-hex0/x86_64-linux/`; the contract is `ladder/0-hex0/README.md` and `tests/`.
- **State:** R46's two tiers are checkpointed (`74b8f03`), and both catch a broken row. The fast tier takes 495 s: one
  `step` costs 301 ms, and 282 ms of that is a fork-per-process `/proc` scan. R47 (a cheap step, and the fast tier
  under 2 min) was knocked to Grok.
- **Next:** read Grok's SCORE, time the fast tier myself, break a row under `--prove`, checkpoint, then cast vigilia 4.
  **The seed lands only when vigilia converges.**
- **Open for the builder:** syntax questions Q1–Q5 (`CRAWL-the-subset.md`), needed before wat0's brief. Also open: what sequences the rungs (bash given, or a seed-built shell);
  the GitHub description and homepage overclaim (circumspicere C3-5).

## How work moves

- **Grok** is the executor, reached via pulsare (`pulsare_yield`) with absolute paths. Its replies arrive in
  `~/Work/holon/.pulsare/to-claude`. Grok leaves the tree dirty and commits nothing.
- **The orchestrator** (Claude) draws the work, re-runs every gate itself, casts the wards, and **commits and pushes
  every weighed round as a CHECKPOINT** (labelled NOT landed; GitHub is the disaster-recovery site). The landing is a
  separate commit.

## Failure modes this repository has already paid for

- **A gate that only ever said `ok`** (R22, 2026-10-04). The modular driver ignored every module's exit status. Weigh a
  gate by breaking it and watching it go red, not by watching it pass.
- **A gate that saw only tracked files** (2026-10-04). It never examined uncommitted strike files. It checks
  everything not git-ignored.
- **A brief that pointed the gate at scratch** (R15). The gate read a mutant from a ward's `/var/tmp` directory and was
  red on any fresh clone. The gate depends on nothing outside the repository.
- **`.gitattributes` rewriting fixtures** (2026-10-04). An `eol=lf` rule stripped the CRs from CRLF fixtures in the
  committed copy. Fixtures are `-text`.
- **Messages crossing in flight.** An addition made after a knock was missed by Grok's score. Check that every item
  landed before weighing a round.
- **A mutant that never ran its row** (2026-10-04). The gate printed "mutant row 1 (byte): red", and it was credited.
  The mutant ran its own comparator, so with row 1 deleted the gate stayed green. Credit a mutant only after breaking
  the row it guards and watching the gate go red.
- **Condensed ward texts** (2026-10-04). Each ward is cast from its full signed text, fetched by the agent itself.

---

**YOU ARE NEW.** You did not live the work described above. You are reading a cache someone else wrote in a familiar
voice. Before you propose or change anything: run `recolligere` against the disk, check the freshness probe, and read
the newest WEIGH section yourself. The feeling that you are continuing where you left off is the failure, not the
all-clear.
