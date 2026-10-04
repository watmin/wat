# HANDOFF — Grok drives until the orchestrator returns

2026-10-04. The orchestrator (Claude) is out of credits until its weekly reset. Grok drives the work in this order and
stops at the limits below. The builder is reachable for rulings. This file is the brief: read it whole, follow it in
order, and record everything in SCORE-hex0.md and, for hex1, SCORE-hex1.md.

## The rules that do not change

- **The seed's bytes never change.** `ladder/0-hex0/x86_64-linux/hex0` is checked by sha256 in the README, row 19.
- **Never land hex0.** Landing is the orchestrator's act, on its return.
- **Do not edit WEIGH-hex0.md.** It is the orchestrator's verdict log. Write your results in SCORE.
- **No vigilia and no ward casts.** That is the builder's ruling: tokens go forward.
- **Disaster recovery.**
  - Commit and push a CHECKPOINT after each finished step: R55, then each hex1 milestone below.
  - The message starts `hex0 CHECKPOINT (NOT landed):` or `hex1 CHECKPOINT (NOT landed):`, and ends with what you
    ran and its result.
  - Never rewrite history, never force-push, never use worktrees, and never run git in `~/Work/holon/` itself.
- **Every result is a command you ran and its output.** A red is never "baseline". Never re-run a red hoping it goes
  green. Read it, then fix the cause.
- **Clojure/EDN syntax only** (LAYOUT rule 8). A spelling that is not settled is ASKED of the builder.

## Step 1 — finish R55 (WEIGH-hex0, "R55")

Do R55 as drawn. Then weigh it yourself, exactly as below, and write a `### R55 — self-weigh` section in SCORE with
each result:
1. Run `tools/verify` live. It must exit 0 with empty stderr, and every file under `.git` must be byte-identical
   before and after (the sha256 of every file under `.git`, sorted).
2. **Break a comparison, never the function.** In a `cp -a` copy under `/var/tmp`, for EACH judge, replace the
   comparison inside it with one that always accepts (for example `a != b` → `False`). Run the gate. It must go red,
   naming that judge's row. Record judge → red line. A judge that stays green is a finding; fix it before Step 2.
3. **Stale index:** `cp -a` the repo to `/var/tmp` and run the gate there with no prior `git status`. It must be
   green, with the copy's `.git` byte-identical before and after. Then repeat after `touch` of every tracked file.
4. **AST lint:** add a `row_*` function containing `_static(0 if a == b else 1)` to a copy. The lint must be red.

Checkpoint and push. Then go to Step 2.

## Step 2 — hex1 (read CRAWL-hex1.md first)

The orchestrator's recommendations in CRAWL-hex1.md are PROVISIONAL defaults. Use them unless the builder rules
otherwise:
- **The language.** hex1 accepts exactly hex0's language (comments end at LF or EOF; whitespace is space, tab, CR,
  LF; hex digits paired), plus two forms:
  - `:c` defines label `c` at the current output offset, counting from 0 at the file's first byte;
  - `%c` emits `target − (offset after the 4 bytes)` as 4 bytes, little-endian, signed 32-bit.
  - A label is ONE byte: printable ASCII, not a hex digit, not whitespace, not `#` `;` `:` `%`.
- **Two passes.** Pass 1 records the labels; `lseek(IN, 0, SEEK_SET)`; pass 2 emits.
- **Statuses.** 0–7 keep hex0's exact meanings and OUT handling (O_NONBLOCK, same file 7, not regular 3, fchmod then
  ftruncate). New statuses, each its own number:
  - 8: a reference to an undefined label;
  - 9: a label defined twice;
  - 10: a displacement that does not fit signed 32 bits;
  - 11: IN cannot be rewound (lseek failed);
  - a byte after `:` or `%` that is not a legal label: use 4, as a bad byte.

  If you find a status that is not on this list, STOP and ask the builder.
- **Layout.**
  - The rung is `ladder/1-hex1/`, holding `README.md` (the contract), `tests/`, and `x86_64-linux/hex1.hex0` (the
    source in hex0's language, which is what hex0 builds) plus `x86_64-linux/hex1.hex1` (the same program written
    with labels).
  - Amend LAYOUT and the gate together, in one commit.
- **The sequencer is bash** (the builder's ruling).
  - Add a top-level executable `build`, amending LAYOUT rule 1's list. It runs only:
    - `ladder/0-hex0/x86_64-linux/hex0 ladder/1-hex1/x86_64-linux/hex1.hex0 out/hex1`;
    - then `out/hex1 ladder/1-hex1/x86_64-linux/hex1.hex1 out/hex1-self`.
  - It builds; the gate checks. The gate never builds and never calls `build`. DESIGN's "What is given" names bash
    as the sequencer until M0's brief.
- **The gate.** Add hex1 rows to `tools/gate/` in round 7's shape:
  - run, observe, then a judge with mutants;
  - no inline comparison;
  - the AST lint covers them.

  The rows:
  - **hex0 parity:** every hex0 fixture gives the same bytes and status through hex1.
  - **labels:** forward and backward references, a reference to the next byte, and the most negative and most
    positive displacements.
  - **refusals:** each of 8–11 on an absent OUT and on an existing OUT.
  - **the self-build:** `out/hex1-self` is byte-identical to `out/hex1`.
  - **the disassembly comments:** row 9's method, with facts in `ladder/1-hex1/x86_64-linux/gate.tsv`.
  - **size**, **syscalls**, and **faults**, including lseek.
- **Milestones.** Checkpoint and push after each one:
  1. README and fixtures, with the gate rows red because no hex1 exists yet;
  2. hex1 builds and parity is green;
  3. all rows green, including the self-build;
  4. the self-weigh (Step 1's protocol, applied to the hex1 rows), recorded in SCORE-hex1.md.

## STOP and ask the builder when

- the seed's bytes would have to change;
- a status, a syntax spelling, or a layout rule is not covered here;
- a gate row can only be written as an inline comparison;
- anything would write outside `~/Work/holon/wat` and `/var/tmp`.

Never improvise around a STOP.

## When the orchestrator returns

It reads RECOVERY, then this file, then SCORE-hex0's and SCORE-hex1's newest sections. It weighs everything since
`52a7cd3` by breaking comparisons itself. Then it lands hex0, and hex1 when it holds.
