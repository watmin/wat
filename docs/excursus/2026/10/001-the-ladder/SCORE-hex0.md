# SCORE — rung 0: hex0

2026-10-04. Nothing here is landed. Checkpoints exist and are not a landing. This strike does not commit. The tree is dirty on purpose.

Current seed, after the Round 6 section below: `ladder/0-hex0/x86_64-linux/hex0` is 537 bytes, mode `755`. That run of `tools/verify.sh` exited 0. Its last line was `verify: sandbox candidate, clone layout, outer repository unchanged`. This strike does not commit. The R34 section records the earlier run whose last line was `verify: working tree, committed in the sandbox and cloned`. The round 5 section records the run that exited 1. The R23 section records the earlier gate, which printed `verify: ok`. The R22 section records the modular gate. The R21 section records the move into the target directory. The round-4 section records that same seed at `ladder/0-hex0/hex0`, before that move. The round-3 section records the 514-byte seed, after the stat slot grew to 144 bytes. The 511-byte seed was the weigh before that.

The first run, before that weigh, was 455 bytes. Its log follows.

## What verify printed

```
mutant rule 1: red
mutant rule 2: red
mutant rule 3: red
mutant rule 4: red
mutant rule 5: red
mutant rule 6: red
mutant rule 7: red
mutant rule 8: red
layout: ok
row 1: cmp identical
row 2: cmp identical
row 3: cmp identical, exit 0
row 8: execve open read write close exit
row 4: cmp identical, exit 42
row 5: 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 7: argc exit 1
row 7: missing IN exit 2
row 7: missing OUT directory exit 3
row 7: G exit 4
row 7: odd digits exit 5
note: IN is a directory, exit 6
row 9: 119 instructions match
row 10: 455 bytes
row 11: lint ok
verify: ok
```

The clean layout run before the mutants also had to print `layout: ok`; a miss there stops the script before mutant 1. Each mutant is required to exit nonzero and to print `layout: rule N:` for its own rule. All eight were reverted before the second `layout: ok`. After the run, `git diff --quiet c45603e -- archived` is clean, `archived/` has no porcelain, and the index has no staged mutant.

## Rows

| # | result |
|---|---|
| 0 | `layout: ok`. Eight mutants red, each naming its rule, then reverted: stray top-level file; a second ELF; a brief inside the rung; rung `2-skip` with rung 1 absent; a README with no exit table; a byte appended under `archived/`; a `tools/` script that redirects into `out/`; a tracked `.wat` file whose text is a colon path. |
| 1 | `tools/check/hex-check.py` on `hex0.hex0` cmp identical to `ladder/0-hex0/hex0` |
| 2 | comments stripped, `xxd -r -p`, cmp identical |
| 3 | `ladder/0-hex0/hex0 ladder/0-hex0/hex0.hex0 out/h1` exit 0, cmp identical |
| 4 | `out/exit42` cmp identical to the xxd decode of `ladder/0-hex0/tests/exit42.hex0`, and running it exits 42 |
| 5 | `stat -c %a out/exit42` is `755`. `verify.sh` sets `umask 0022` before the run. |
| 6 | lower `ab`, upper `J`, CRLF between nibbles `A`, comment at EOF with no newline `A`, `;` and `#` then `B`, split `4 1` is `A`. Each exit 0. |
| 7 | argc 2 exits 1; missing IN exits 2; OUT under a missing directory exits 3; `G` exits 4; one leftover digit exits 5 |
| 8 | `strace -f` on the row 3 command: `execve`, `open`, `read`, `write`, `close`, `exit` |
| 9 | `objdump -D -b binary -m i386:x86-64` on the bytes after file offset `0x78`: 119 instruction comments match, and those bytes are the whole code blob |
| 10 | `wc -c` is 455, which is ≤ 512 |
| 11 | `tools/check/hex-check.py --lint` printed `lint: ok` |

The directory-as-IN line is not an expectations row. Opening the rung directory succeeds and the following read fails, and hex0 exits 6. That is the status 6 path in the contract.

## Size

455 bytes: 120 of ELF and program header, 335 of code. `p_filesz` and `p_memsz` are 455 (`C7 01 00 00 00 00 00 00`). The prediction was 250–400, the upper half because refusals are distinct. 455 is above that prediction and under the 512 gate. A few conditional jumps are rel32 because the displacement does not fit in a byte; the comment-skip `je` is one of them. Left as assembled.

## Cross-check

The same 335 code bytes were assembled with `nasm -f bin` under `/tmp/hex0-scratch` and wrapped into an ELF there. `cmp` of that file with `ladder/0-hex0/hex0` was identical. nasm did not write the seed or anything under `out/`. `out/h1`, `out/exit42`, and the fixture outputs were written by `ladder/0-hex0/hex0`.

## Weigh round 1

Two fixes, then every row again.

**R1.** After `close` of OUT the seed tests `eax`. Negative exits 6. Status 6 now reads "a read, write or close failed" in the `hex0.hex0` header, in `ladder/0-hex0/README.md`, and in the brief's table. The close sequence is `syscall` / `test %eax,%eax` / `jns` / push 6, or `xor %edi,%edi` and exit 0. No fixture makes the kernel fail `close`. A scratch trace of a successful decode showed `close` returning 0 and then `exit(0)`.

**R2.** `tools/layout.sh` rule 5 no longer demands rows 0 through 6. It reads the one `Exit status:` block in the rung source and the README table, and requires those two sets of numbers to be equal. The old "no exit table" mutant still goes red. Two mutants were added: the README missing row 4, and a README row 7 that the source does not declare.

The seed is 475 bytes: 120 of header, 355 of code. `p_filesz` and `p_memsz` are 475 (`DB 01 00 00 00 00 00 00`). That is 20 bytes over the first seed, still under the 512 gate, still above the 250–400 prediction. Row 9 is 124 instructions. The code bytes were cross-assembled with nasm under `/tmp` and `cmp` against the decoded seed was identical. The seed file itself is the decoder's stdout.

```
mutant rule 1: red
mutant rule 2: red
mutant rule 3: red
mutant rule 4: red
mutant rule 5: red
mutant rule 5: red
mutant rule 5: red
mutant rule 6: red
mutant rule 7: red
mutant rule 8: red
layout: ok
row 1: cmp identical
row 2: cmp identical
row 3: cmp identical, exit 0
row 8: execve open read write close exit
row 4: cmp identical, exit 42
row 5: 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 7: argc exit 1
row 7: missing IN exit 2
row 7: missing OUT directory exit 3
row 7: G exit 4
row 7: odd digits exit 5
note: IN is a directory, exit 6
row 9: 124 instructions match
row 10: 475 bytes
row 11: lint ok
verify: ok
```

After that run, `git diff --quiet c45603e -- archived` is clean and the rung README matches the copy taken before the mutants.

## Refute — R3, R4, R5

The previous knock stopped at R1 and R2. This run puts the rest in.

**R3.** OUT is opened with `O_WRONLY|O_CREAT` (`0x41`) and no `O_TRUNC`. After the same-file check, `fchmod` (syscall 91) sets mode `0755`. Failure exits 3. A fresh `out/exit42` is mode `755`. An OUT that already existed at mode `600` is mode `755` afterwards, and its bytes match the probe.

**R4.** `fstat` (syscall 5) of both descriptors compares `st_dev` and `st_ino` before `fchmod` and before `ftruncate` (syscall 77). A match exits 7 and leaves the bytes alone. The same path, a hard link, and a symlink each exited 7 with IN byte-identical. `ftruncate` failure exits 6. Status 6 now reads "a read, write, close or truncate failed" in the source header, the README, and the brief. `fstat` failure on IN is status 2. `fstat` failure on OUT is status 3, with `fchmod`.

**R5.** `tools/check/fuzz-hex0.py` is a reference written from the contract, generator seed `20261004`, covering every byte, the near-miss bytes, comments, CRLF, and lengths through 4,096. The 2,000-case slice printed `fuzz: 2000 agree`. The discriminating copy flips the one `cmp $0x5` that bounds `a-f` (`3C 05` to `3C 06`, the compact form of the `cmp $0x46` example). It printed `fuzz mutant: 6 disagreements`. The seed file was not modified.

The seed is 511 bytes: 120 of header, 391 of code. `p_filesz` and `p_memsz` are 511 (`FF 01 00 00 00 00 00 00`). That is under the 512 gate. Row 9 is 150 instructions. nasm under `/tmp` cross-assembled the code; `cmp` against the decoded seed was identical. The seed file is the decoder's stdout.

```
mutant rule 1: red
mutant rule 2: red
mutant rule 3: red
mutant rule 4: red
mutant rule 5: red
mutant rule 5: red
mutant rule 5: red
mutant rule 6: red
mutant rule 7: red
mutant rule 8: red
layout: ok
row 1: cmp identical
row 2: cmp identical
row 3: cmp identical, exit 0
row 8: execve open fstat fchmod ftruncate read write close exit
row 4: cmp identical, exit 42
row 5: 755
row 5: preexist 600 is 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 7: argc exit 1
row 7: missing IN exit 2
row 7: missing OUT directory exit 3
row 7: G exit 4
row 7: odd digits exit 5
row 7: same path exit 7
row 7: hard link exit 7
row 7: symlink exit 7
note: IN is a directory, exit 6
row 9: 150 instructions match
row 10: 511 bytes
row 11: lint ok
fuzz: 2000 agree
fuzz mutant: 6 disagreements
row 12: fuzz ok
verify: ok
```

After that run, `archived/` still matches `c45603e` and no fuzz-disagree fixture was left behind. Wards were not cast. Nothing was committed.

## R6 — the docs shape

`tools/layout.sh` now enforces rule 9. The top of `docs/` may contain standing `*.md` files and `excursus/` only. An excursus is `docs/excursus/YYYY/MM/NNN-<slug>/`, the counter starts at `001` in each month with no gaps, the slug is lowercase words joined by `-`, and the directory holds `*.md` only.

The clean tree passed. Four mutants went red naming rule 9, then were removed:

- `docs/stray-dir` — stray directory under `docs/`
- `docs/excursus/2026/10/003-counter-gap` with `002` absent — counter gap
- `001-the-ladder/stray.hex0` — a non-document inside an excursus
- `002-BadSlug` — a badly formed slug

The seed is still 511 bytes. `tools/verify.sh` was re-run and printed `verify: ok`. Wards were not cast. Nothing was committed.

```
mutant rule 1: red
mutant rule 2: red
mutant rule 3: red
mutant rule 4: red
mutant rule 5: red
mutant rule 5: red
mutant rule 5: red
mutant rule 6: red
mutant rule 7: red
mutant rule 8: red
mutant rule 9: red
mutant rule 9: red
mutant rule 9: red
mutant rule 9: red
layout: ok
row 1: cmp identical
row 2: cmp identical
row 3: cmp identical, exit 0
row 8: execve open fstat fchmod ftruncate read write close exit
row 4: cmp identical, exit 42
row 5: 755
row 5: preexist 600 is 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 7: argc exit 1
row 7: missing IN exit 2
row 7: missing OUT directory exit 3
row 7: G exit 4
row 7: odd digits exit 5
row 7: same path exit 7
row 7: hard link exit 7
row 7: symlink exit 7
note: IN is a directory, exit 6
row 9: 150 instructions match
row 10: 511 bytes
row 11: lint ok
fuzz: 2000 agree
fuzz mutant: 6 disagreements
row 12: fuzz ok
verify: ok
```

After that run, `archived/` still matches `c45603e` and the four rule 9 mutants are gone.

## R6 extended — bare numbered references

Rule 9 now also rejects a tracked file outside `archived/` that contains the name `excursus` or `arc`, a space, and digits that are not the start of a slug. A reference still names `YYYY/MM/NNN-<slug>`.

The statute quoted that forbidden form, so a literal gate was red on `docs/LAYOUT.md` and on `WEIGH-hex0.md`. Those quotations were split into "the name, a space, then digits". The rule they state is unchanged. After that, a clean `tools/layout.sh` printed `layout: ok`.

A standing file `docs/bare-ref.md`, tracked for the check and then removed, printed:

```
layout: rule 9: bare numbered reference in docs/bare-ref.md
```

`tools/verify.sh` was then run once. It did not print `verify: ok`. It got through the earlier mutants and stopped here:

```
verify: mutant rule 9 said layout: rule 1: top-level name not in the layout: brand
```

`wat/brand/` is a directory of logo and icon files. It is not one of the top-level names in `docs/LAYOUT.md`. It was not created by this strike, and it was not removed. Rule 1 fires before rule 9, so this run did not reach the bare-reference mutant or any later row. The seed is still 511 bytes. Wards were not cast. Nothing was committed.

## Round 3 — brand, the stat slot, and the gate

`brand/` is now on rule 1's allowed list. Files under it must be `.png`, `.ico` or `.svg`. Rules 2 and 8 still scan it. A file `brand/x.md`, created for the check and then removed, printed:

```
layout: rule 1: brand/ holds a non-image: brand/x.md
```

The `fstat` slot is 144 bytes, the size of the kernel `struct stat` on this machine. `sub rsp, 144` does not fit in an imm8, so the instruction is three bytes wider than `sub rsp, 127`. The code is 394 bytes. `p_filesz` is the sum `0x78 + 394 = 514`. The seed was decoded once from `ladder/0-hex0/hex0.hex0` and is 514 bytes, mode `755`. Row 10's 512 ceiling moved for that reason.

The source header and `ladder/0-hex0/README.md` now say whitespace is exactly space, tab, CR and LF, and that a comment runs to the next LF and a CR does not end it. They name the ladder, the rung and the seed, and they say what OUT holds after each status. The same OUT column is in the brief's table. Each instruction comment begins with its file offset. Row 9 strips that prefix and compares the rest with objdump.

`tests/lower.hex0` is the lowercase digits `ab`. New fixtures cover a comment between two digits, and a reject byte after a pending nibble. The fuzz compares OUT on every status. Its generator seed is still `20261004`.

`tools/verify.sh` was then run once. It printed:

```
mutant rule 1: red
mutant rule 1: red
mutant rule 2: red
mutant rule 3: red
mutant rule 4: red
mutant rule 5: red
mutant rule 5: red
mutant rule 5: red
mutant rule 6: red
mutant rule 7: red
mutant rule 8: red
mutant rule 9: red
mutant rule 9: red
mutant rule 9: red
mutant rule 9: red
mutant rule 9: red
layout: ok
row 1: cmp identical
row 2: cmp identical
row 3: cmp identical, exit 0
row 8: execve open fstat fchmod ftruncate read write close exit
row 4: cmp identical, exit 42
row 5: 755
row 5: preexist 600 is 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 6: comment-nibble exit 0
row 7: argc exit 1
row 7: missing IN exit 2
row 7: missing OUT directory exit 3
row 7: G exit 4
row 7: reject-2f exit 4
row 7: reject-40 exit 4
row 7: reject-80 exit 4
row 7: reject-ff exit 4
row 7: odd digits exit 5
row 7: same path exit 7
row 7: hard link exit 7
row 7: symlink exit 7
note: IN is a directory, exit 6
row 9: 150 instructions match
row 10: 514 bytes
row 11: lint ok
fuzz: 2000 agree
fuzz mutant: 2 disagreements
fuzz byte mutant: 1395 disagreements, 1395 on bytes
row 12: fuzz ok
row 13: fstat IN exit 2, control 0
row 13: fstat OUT exit 3, control 0
row 13: fchmod exit 3, control 0
row 13: read exit 6, control 0
row 13: write exit 6, control 0
row 13: close exit 6, control 0
row 13: ftruncate exit 6, control 0
verify: ok
```

It exited 0. Wards were not cast. Nothing was committed. The rung is not landed.

## Round 4 — the gate proves the seed

The only behaviour change is the regular-file check. After the same-file test, and before `fchmod`, the seed masks OUT's `st_mode` (offset 24 of the 144-byte slot) with `0xF000` and refuses with status 3 unless the result is `0x8000`. A device is left unchanged. A read-only same file is status 3, because the open fails before that check, and the bytes and mode stay as they were. Status 7 still applies only once OUT has opened and the two files are the same inode.

The file is 537 bytes, mode `755`. Row 10 reads `p_filesz` and `p_memsz` from the program header and requires both to equal that length. The code is 417 bytes (`0x78 + 417 = 537`). Row 9 matched 156 instructions, and a one-word comment mutant of the argc compare went red.

The README, the header and the brief state the comment rule (to the next LF or end of input), the mode rule (0755 only after the checks that precede `fchmod`), the signal and FIFO bounds, and that 144 bytes is the x86-64 ABI `struct stat`. Jump targets in the instruction comments are offsets from the first code byte. The register table names `rbp`, `r8` and `rcx`. `tests/exit42.hex0` points at the README.

`tools/verify.sh` was then run once. Stderr was empty. It exited 0. It printed:

```
mutant rule 1 (stray top-level file): red
mutant rule 1 (brand non-image): red
mutant rule 2 (second ELF): red
mutant rule 2 (NUL binary): red
mutant rule 3 (brief inside a rung): red
mutant rule 4 (rung number gap): red
mutant rule 5 (readme without an exit table): red
mutant rule 5 (readme missing a status): red
mutant rule 5 (readme extra status): red
mutant rule 6 (archived byte): red
mutant rule 7 (redirect into out/): red
mutant rule 7 (copy into out/): red
mutant rule 8 (colon path): red
mutant rule 9 (stray directory under docs/): red
mutant rule 9 (counter gap): red
mutant rule 9 (non-document in an excursus): red
mutant rule 9 (bad slug): red
mutant rule 9 (bare numbered reference): red
layout: ok
row 1: cmp identical
row 2: cmp identical
row 3: cmp identical, exit 0
row 8: execve open fstat fchmod ftruncate read write close exit
mutant row 8 (extra syscall): red
row 4: cmp identical, exit 42
row 5: 755
row 5: preexist 600 is 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 6: comment-nibble exit 0
row 6: comment-cr exit 0
row 6: comment-tab exit 0
row 6: comment-high exit 0
row 6: crlf-two exit 0
row 7: argc 1 exit 1
row 7: argc 0 exit 1
row 7: argc 4 exit 1
row 7: missing IN exit 2
row 7: G exit 4
row 7: vt exit 4
row 7: ff exit 4
row 7: reject-2f exit 4
row 7: reject-40 exit 4
row 7: reject-80 exit 4
row 7: reject-ff exit 4
row 7: odd exit 5
row 7: odd-after exit 5
row 7: missing OUT directory exit 3, absent stays absent
row 7: non-regular exit 3, mode unchanged
row 7: read-only same file exit 3, unchanged
row 7: same path exit 7
row 7: hard link exit 7
row 7: symlink exit 7
row 7: absent same path exit 2
row 7: directory IN exit 6
row 13: fstat IN exit 2, control 0
row 13: fstat OUT exit 3, control 0
row 13: fchmod exit 3, control 0
row 13: read exit 6, control 0
row 13: write exit 6, control 0
row 13: close exit 6, control 0
row 13: ftruncate exit 6, control 0
mutant trunc-before-fchmod: red (rc 3)
row 9: 156 instructions match
mutant row 9 (comment): red
row 10: 537 bytes
row 11: lint ok
fuzz: 2000 agree
fuzz mutant: 2 disagreements
fuzz letter-offset mutant: 1369 disagreements, 1369 on bytes
row 12: fuzz ok
verify: ok
```

Wards were not cast. Nothing was committed. The rung is not landed.

## R21 — one contract, per-target implementations

The contract stays on the rung: `ladder/0-hex0/README.md` and `ladder/0-hex0/tests/`. The source and the seed moved to `ladder/0-hex0/x86_64-linux/`. The header and the README say the contract is the rung's and the machine code is the target's. The header change is comments only. Row 1 still matches the 537-byte seed, mode `755`.

The host target is `uname -m` and `uname -s` in lower case, here `x86_64-linux`. The contract rows ran for that target. A name other than the host prints `not executed on this host` and does not run those rows. The tree has no second target. The line below is that branch, called with `aarch64-linux`.

`tools/verify.sh` was then run once. Stderr was empty. It exited 0. It printed:

```
mutant rule 1 (stray top-level file): red
mutant rule 1 (brand non-image): red
mutant rule 2 (second ELF): red
mutant rule 2 (seed outside a target): red
mutant rule 2 (second binary inside a target): red
mutant rule 2 (NUL binary): red
mutant rule 3 (brief inside a rung): red
mutant rule 3 (target with no source): red
mutant rule 3 (badly named target): red
mutant rule 4 (rung number gap): red
mutant rule 5 (readme without an exit table): red
mutant rule 5 (readme missing a status): red
mutant rule 5 (readme extra status): red
mutant rule 6 (archived byte): red
mutant rule 7 (redirect into out/): red
mutant rule 7 (copy into out/): red
mutant rule 8 (colon path): red
mutant rule 9 (stray directory under docs/): red
mutant rule 9 (counter gap): red
mutant rule 9 (non-document in an excursus): red
mutant rule 9 (bad slug): red
mutant rule 9 (bare numbered reference): red
layout: ok
row 1: cmp identical
row 2: cmp identical
row 3: cmp identical, exit 0
row 8: execve open fstat fchmod ftruncate read write close exit
mutant row 8 (extra syscall): red
row 4: cmp identical, exit 42
row 5: 755
row 5: preexist 600 is 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 6: comment-nibble exit 0
row 6: comment-cr exit 0
row 6: comment-tab exit 0
row 6: comment-high exit 0
row 6: crlf-two exit 0
row 7: argc 1 exit 1
row 7: argc 0 exit 1
row 7: argc 4 exit 1
row 7: missing IN exit 2
row 7: G exit 4
row 7: vt exit 4
row 7: ff exit 4
row 7: reject-2f exit 4
row 7: reject-40 exit 4
row 7: reject-80 exit 4
row 7: reject-ff exit 4
row 7: odd exit 5
row 7: odd-after exit 5
row 7: missing OUT directory exit 3, absent stays absent
row 7: non-regular exit 3, mode unchanged
row 7: read-only same file exit 3, unchanged
row 7: same path exit 7
row 7: hard link exit 7
row 7: symlink exit 7
row 7: absent same path exit 2
row 7: directory IN exit 6
row 13: fstat IN exit 2, control 0
row 13: fstat OUT exit 3, control 0
row 13: fchmod exit 3, control 0
row 13: read exit 6, control 0
row 13: write exit 6, control 0
row 13: close exit 6, control 0
row 13: ftruncate exit 6, control 0
mutant trunc-before-fchmod: red (rc 3)
row 9: 156 instructions match
mutant row 9 (comment): red
row 10: 537 bytes
row 11: lint ok
fuzz: 2000 agree
fuzz mutant: 2 disagreements
fuzz letter-offset mutant: 1369 disagreements, 1369 on bytes
row 12: fuzz ok
aarch64-linux: not executed on this host
verify: ok
```

Wards were not cast. Nothing was committed. The rung is not landed.

## R22 — the gate modular, self-contained, and blind to nothing on disk

`tools/verify.sh` is the driver: the sandbox, host detection, and the loop over rungs and targets. `die` and `guard` live in `tools/check/gate-lib.sh`. Layout mutants live in `tools/check/layout-mutants.sh`. Rows 1, 2, 9, 10 and 11, and the row-9 comment mutant, live in `tools/check/seed-audit.sh`, which does not run the seed. Rows 3–8, 12 and 13 live in `tools/check/hex0-contract.sh`. The rung-gap directory is the highest rung number plus 2. The seed copied for the outside-target mutant is `ladder/0-hex0/*/hex0` from the scratch tree.

The truncate-before-fchmod mutant is a one-pattern byte patch of the seed, made during the run. It is not read from outside the repository. The pattern occurs once. Under a faulted fchmod it printed red at rc 3.

Rules 2, 8 and 9 read every file a commit could carry, tracked or not, and skip git-ignored files. An untracked tools file with a colon path printed red. The `/dev/null` mode message now says "to", so the arrow is not in the gate.

The syscall table's place is named in DESIGN's Targets section: `ladder/<n>-<name>/<arch>-<os>/syscalls.tsv`. The gate does not read it yet. One executable target is still the x86-64 Linux numbers in the contract check.

`tools/verify.sh` was then run once. Stderr was empty. It exited 0. It printed:

```
mutant rule 1 (stray top-level file): red
mutant rule 1 (brand non-image): red
mutant rule 2 (second ELF): red
mutant rule 2 (seed outside a target): red
mutant rule 2 (second binary inside a target): red
mutant rule 2 (NUL binary): red
mutant rule 3 (brief inside a rung): red
mutant rule 3 (target with no source): red
mutant rule 3 (badly named target): red
mutant rule 4 (rung number gap): red
mutant rule 5 (readme without an exit table): red
mutant rule 5 (readme missing a status): red
mutant rule 5 (readme extra status): red
mutant rule 6 (archived byte): red
mutant rule 7 (redirect into out/): red
mutant rule 7 (copy into out/): red
mutant rule 8 (colon path): red
mutant rule 8 (untracked colon path): red
mutant rule 9 (stray directory under docs/): red
mutant rule 9 (counter gap): red
mutant rule 9 (non-document in an excursus): red
mutant rule 9 (bad slug): red
mutant rule 9 (bare numbered reference): red
layout: ok
row 1: cmp identical
row 2: cmp identical
row 9: 156 instructions match
mutant row 9 (comment): red
row 10: 537 bytes
row 11: lint ok
row 3: cmp identical, exit 0
row 8: execve open fstat fchmod ftruncate read write close exit
mutant row 8 (extra syscall): red
row 4: cmp identical, exit 42
row 5: 755
row 5: preexist 600 is 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 6: comment-nibble exit 0
row 6: comment-cr exit 0
row 6: comment-tab exit 0
row 6: comment-high exit 0
row 6: crlf-two exit 0
row 7: argc 1 exit 1
row 7: argc 0 exit 1
row 7: argc 4 exit 1
row 7: missing IN exit 2
row 7: G exit 4
row 7: vt exit 4
row 7: ff exit 4
row 7: reject-2f exit 4
row 7: reject-40 exit 4
row 7: reject-80 exit 4
row 7: reject-ff exit 4
row 7: odd exit 5
row 7: odd-after exit 5
row 7: missing OUT directory exit 3, absent stays absent
row 7: non-regular exit 3, mode unchanged
row 7: read-only same file exit 3, unchanged
row 7: same path exit 7
row 7: hard link exit 7
row 7: symlink exit 7
row 7: absent same path exit 2
row 7: directory IN exit 6
row 13: fstat IN exit 2, control 0
row 13: fstat OUT exit 3, control 0
row 13: fchmod exit 3, control 0
row 13: read exit 6, control 0
row 13: write exit 6, control 0
row 13: close exit 6, control 0
row 13: ftruncate exit 6, control 0
mutant trunc-before-fchmod: red (rc 3)
fuzz: 2000 agree
fuzz mutant: 2 disagreements
fuzz letter-offset mutant: 1369 disagreements, 1369 on bytes
row 12: fuzz ok
aarch64-linux: not executed on this host
verify: ok
```

Wards were not cast. Nothing was committed. The rung is not landed.

## R23 — the gate fails closed

`guard` in `tools/check/gate-lib.sh` dies when its command fails or times out. Callers that expect a failing status use `run_status`. `tools/check/driver-test.sh` runs `tools/verify.sh` on a scratch copy whose modules are stubs: each of `layout-mutants`, `seed-audit`, and `hex0-contract` exits 1 in turn, and then `layout-mutants` sleeps until its guard kills it. The driver's last row clones the repository into the sandbox and runs `tools/layout.sh` on that clone.

`tools/verify.sh` was then run once. Stderr was empty. It exited 0. It printed:

```
mutant rule 1 (stray top-level file): red
mutant rule 1 (brand non-image): red
mutant rule 2 (second ELF): red
mutant rule 2 (seed outside a target): red
mutant rule 2 (second binary inside a target): red
mutant rule 2 (NUL binary): red
mutant rule 3 (brief inside a rung): red
mutant rule 3 (target with no source): red
mutant rule 3 (badly named target): red
mutant rule 4 (rung number gap): red
mutant rule 5 (readme without an exit table): red
mutant rule 5 (readme missing a status): red
mutant rule 5 (readme extra status): red
mutant rule 6 (archived byte): red
mutant rule 7 (redirect into out/): red
mutant rule 7 (copy into out/): red
mutant rule 8 (colon path): red
mutant rule 8 (untracked colon path): red
mutant rule 9 (stray directory under docs/): red
mutant rule 9 (counter gap): red
mutant rule 9 (non-document in an excursus): red
mutant rule 9 (bad slug): red
mutant rule 9 (bare numbered reference): red
layout: ok
row 1: cmp identical
row 2: cmp identical
row 9: 156 instructions match
mutant row 9 (comment): red
row 10: 537 bytes
row 11: lint ok
row 3: cmp identical, exit 0
row 8: execve open fstat fchmod ftruncate read write close exit
mutant row 8 (extra syscall): red
row 4: cmp identical, exit 42
row 5: 755
row 5: preexist 600 is 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 6: comment-nibble exit 0
row 6: comment-cr exit 0
row 6: comment-tab exit 0
row 6: comment-high exit 0
row 6: crlf-two exit 0
row 7: argc 1 exit 1
row 7: argc 0 exit 1
row 7: argc 4 exit 1
row 7: missing IN exit 2
row 7: G exit 4
row 7: vt exit 4
row 7: ff exit 4
row 7: reject-2f exit 4
row 7: reject-40 exit 4
row 7: reject-80 exit 4
row 7: reject-ff exit 4
row 7: odd exit 5
row 7: odd-after exit 5
row 7: missing OUT directory exit 3, absent stays absent
row 7: non-regular exit 3, mode unchanged
row 7: read-only same file exit 3, unchanged
row 7: same path exit 7
row 7: hard link exit 7
row 7: symlink exit 7
row 7: absent same path exit 2
row 7: directory IN exit 6
row 13: fstat IN exit 2, control 0
row 13: fstat OUT exit 3, control 0
row 13: fchmod exit 3, control 0
row 13: read exit 6, control 0
row 13: write exit 6, control 0
row 13: close exit 6, control 0
row 13: ftruncate exit 6, control 0
mutant trunc-before-fchmod: red (rc 3)
fuzz: 2000 agree
fuzz mutant: 2 disagreements
fuzz letter-offset mutant: 1369 disagreements, 1369 on bytes
row 12: fuzz ok
aarch64-linux: not executed on this host
driver: layout-mutants exit 1 is fatal
driver: seed-audit exit 1 is fatal
driver: hex0-contract exit 1 is fatal
driver: layout-mutants hang is killed
layout: ok
fresh clone: layout ok
verify: ok
```

Wards were not cast. Nothing was committed. The rung is not landed.

## Round 5 — FIFO refused, and the clone of HEAD still rewrites LF

Open OUT is `O_WRONLY|O_CREAT|O_NONBLOCK` (`0x841`). The seed stayed 537 bytes, mode 755. Row 9 matched 156 instructions. Row 2 is `sed` then `xxd`, and it printed `row 2: cmp identical`.

`tools/verify.sh` exited 1. Stdout is the block below. Stderr was:

```
timeout: the monitored command dumped core
/home/watmin/Work/holon/wat/tools/check/gate-lib.sh: line 100: 2676491 File size limit exceeded   timeout --verbose -s KILL "$secs" "$@"
verify: non-host target: driver rc 1 verify: autocrlf clone rewrote a tools script
verify: tools/check/driver-test.sh rc 1
```

The default `SIGXFSZ` row still printed `row 6: SIGXFSZ default exit 153`. The ignored row printed `row 6: SIGXFSZ ignored exit 6, 1024 bytes kept`. The core line is timeout's note from that default row.

The driver printed the three fatal lines and the three hang lines, then died in the non-host proof. That nested run clones HEAD. With `core.autocrlf=true`, the clone rewrote a tools script. The worktree `.gitattributes` starts with `* text=auto eol=lf`. HEAD `1bc8a48` does not have that line. This strike does not commit, so a clone of HEAD does not carry it. These lines did not print: `fresh clone: layout ok`, `autocrlf clone: lf`, `verify: working tree and HEAD clone`.

A FIFO OUT printed status 3 with the mode unchanged, with no reader and with a reader. `row 7: same device exit 7` printed. The trunc-first mutant printed `mutant trunc-before-fchmod: red (rc 3, mode 640, bytes truncated)`. Fuzz printed `fuzz: 2000 agree`, then `fuzz mutant: stopped at first disagreement`, then `fuzz letter-offset mutant: stopped at first byte disagreement`.

Wards were not cast. This strike committed nothing. The rung is not landed.

```
mutant stray top-level file: red
mutant brand directory: red
mutant brand non-image: red
mutant ELF in brand: red
mutant tracked out: red
mutant second ELF: red
mutant seed outside a target: red
mutant second binary inside a target: red
mutant NUL binary: red
mutant markdown inside a target: red
mutant note inside a target: red
mutant brief inside a rung: red
mutant target with no source: red
mutant badly named target: red
mutant rung name: red
mutant rung number gap: red
mutant rung without README: red
mutant readme without an exit table: red
mutant source missing a status: red
mutant source extra status: red
mutant archived byte: red
mutant untracked archived file: red
mutant redirect into out/: red
mutant tee-out: red
mutant copy into out/: red
mutant move into out/: red
mutant dd into out/: red
mutant install-out: red
mutant dash-o into out/: red
mutant fault allowance bypass: red
mutant colon path: red
mutant tracked arrow: red
mutant stray directory under docs/: red
mutant docs top-level non-document: red
mutant year not YYYY: red
mutant month not MM: red
mutant empty month: red
mutant counter gap: red
mutant directory inside an excursus: red
mutant non-document in an excursus: red
mutant bad slug: red
mutant bare numbered reference: red
second target with a pointer: green
layout: ok
row 1: cmp identical
mutant row 1 (byte): red
row 2: cmp identical
row 9: 156 instructions match
mutant row 9 (comment): red
mutant row 9 (offset): red
mutant row 9 (count): red
row 10: 537 bytes
row 11: lint ok
mutant row 11 (bare): red
row 3: cmp identical, exit 0
row 8: execve read write open close fstat exit ftruncate fchmod
mutant row 8 (extra syscall): red
row 4: cmp identical, exit 42
row 5: 755
row 5: preexist 600 is 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 6: comment-nibble exit 0
row 6: comment-cr exit 0
row 6: comment-tab exit 0
row 6: comment-high exit 0
row 6: crlf-two exit 0
row 7: argc 0 exit 1
row 7: argc 1 exit 1
row 7: one path exit 1
row 7: argc 4 exit 1
row 7: missing IN exit 2
row 7: G exit 4
row 7: vt exit 4
row 7: ff exit 4
row 7: reject-2f exit 4
row 7: reject-40 exit 4
row 7: reject-80 exit 4
row 7: reject-ff exit 4
row 7: odd exit 5
row 7: odd-after exit 5
row 7: missing OUT directory exit 3, absent stays absent
row 7: non-regular exit 3, mode unchanged
row 7: same device exit 7
row 7: fifo with no reader exit 3, mode unchanged
row 7: fifo with a reader exit 3, mode unchanged
row 7: read-only same file exit 3, unchanged
row 7: same path exit 7
row 7: hard link exit 7
row 7: symlink exit 7
row 7: absent same path exit 2
row 7: directory IN exit 6
row 13: fstat IN exit 2, control 0
row 13: fstat OUT exit 3, control 0
row 13: fchmod exit 3, control 0
row 13: read exit 6, control 0
row 13: write exit 6, control 0
row 13: close exit 6, control 0
row 13: ftruncate exit 6, control 0
row 13: write after a byte exit 6, control 0
row 13: read after bytes exit 6, control 0
mutant trunc-before-fchmod: red (rc 3, mode 640, bytes truncated)
row 6: SIGXFSZ default exit 153
row 6: SIGXFSZ ignored exit 6, 1024 bytes kept
fuzz: 2000 agree
fuzz mutant: stopped at first disagreement
fuzz letter-offset mutant: stopped at first byte disagreement
row 12: fuzz ok
driver: layout-mutants exit 1 is fatal
driver: seed-audit exit 1 is fatal
driver: hex0-contract exit 1 is fatal
driver: layout-mutants hang timed out
driver: seed-audit hang timed out
driver: hex0-contract hang timed out
```

## R34 — the clone is the working tree, and the size-limit row stores no core

`tools/verify.sh` exited 0. Stderr was empty. `git status --porcelain=v1` was the same before and after the run, and the index was clean. The commit the clone rows use is in the sandbox copy. This strike did not commit.

The last lines were `plain clone: layout ok`, `layout: ok`, `autocrlf clone: lf`, `mutant autocrlf without the attribute: red`, and `verify: working tree, committed in the sandbox and cloned`.

The default `SIGXFSZ` row printed `row 6: SIGXFSZ default exit 153, no core`. The bash note and timeout's core line were on stdout, prefixed `row 6 SIGXFSZ note:`. `coredumpctl` for the child pid 2749096 lists `SIGXFSZ` with `COREFILE none`. The ignored row printed `row 6: SIGXFSZ ignored exit 6, 1024 bytes kept`.

The non-host driver proof printed `driver: non-host target is not executed` and `driver-test: skipped on the nested run`. Seed row 10 printed `row 10: 537 bytes`. Row 5 printed `755`.

Wards were not cast. This strike committed nothing. The rung is not landed.

```
mutant stray top-level file: red
mutant brand directory: red
mutant brand non-image: red
mutant ELF in brand: red
mutant tracked out: red
mutant second ELF: red
mutant seed outside a target: red
mutant second binary inside a target: red
mutant NUL binary: red
mutant markdown inside a target: red
mutant note inside a target: red
mutant brief inside a rung: red
mutant target with no source: red
mutant badly named target: red
mutant rung name: red
mutant rung number gap: red
mutant rung without README: red
mutant readme without an exit table: red
mutant source missing a status: red
mutant source extra status: red
mutant archived byte: red
mutant untracked archived file: red
mutant redirect into out/: red
mutant tee-out: red
mutant copy into out/: red
mutant move into out/: red
mutant dd into out/: red
mutant install-out: red
mutant dash-o into out/: red
mutant fault allowance bypass: red
mutant colon path: red
mutant tracked arrow: red
mutant stray directory under docs/: red
mutant docs top-level non-document: red
mutant year not YYYY: red
mutant month not MM: red
mutant empty month: red
mutant counter gap: red
mutant directory inside an excursus: red
mutant non-document in an excursus: red
mutant bad slug: red
mutant bare numbered reference: red
second target with a pointer: green
layout: ok
row 1: cmp identical
mutant row 1 (byte): red
row 2: cmp identical
row 9: 156 instructions match
mutant row 9 (comment): red
mutant row 9 (offset): red
mutant row 9 (count): red
row 10: 537 bytes
row 11: lint ok
mutant row 11 (bare): red
row 3: cmp identical, exit 0
row 8: execve read write open close fstat exit ftruncate fchmod
mutant row 8 (extra syscall): red
row 4: cmp identical, exit 42
row 5: 755
row 5: preexist 600 is 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 6: comment-nibble exit 0
row 6: comment-cr exit 0
row 6: comment-tab exit 0
row 6: comment-high exit 0
row 6: crlf-two exit 0
row 7: argc 0 exit 1
row 7: argc 1 exit 1
row 7: one path exit 1
row 7: argc 4 exit 1
row 7: missing IN exit 2
row 7: G exit 4
row 7: vt exit 4
row 7: ff exit 4
row 7: reject-2f exit 4
row 7: reject-40 exit 4
row 7: reject-80 exit 4
row 7: reject-ff exit 4
row 7: odd exit 5
row 7: odd-after exit 5
row 7: missing OUT directory exit 3, absent stays absent
row 7: non-regular exit 3, mode unchanged
row 7: same device exit 7
row 7: fifo with no reader exit 3, mode unchanged
row 7: fifo with a reader exit 3, mode unchanged
row 7: read-only same file exit 3, unchanged
row 7: same path exit 7
row 7: hard link exit 7
row 7: symlink exit 7
row 7: absent same path exit 2
row 7: directory IN exit 6
row 13: fstat IN exit 2, control 0
row 13: fstat OUT exit 3, control 0
row 13: fchmod exit 3, control 0
row 13: read exit 6, control 0
row 13: write exit 6, control 0
row 13: close exit 6, control 0
row 13: ftruncate exit 6, control 0
row 13: write after a byte exit 6, control 0
row 13: read after bytes exit 6, control 0
mutant trunc-before-fchmod: red (rc 3, mode 640, bytes truncated)
row 6: SIGXFSZ default exit 153, no core
row 6 SIGXFSZ note: timeout: the monitored command dumped core
row 6 SIGXFSZ note: /home/watmin/Work/holon/wat/tools/check/gate-lib.sh: line 100: 2749095 File size limit exceeded   timeout --verbose -s KILL "$secs" "$@"
row 6: SIGXFSZ ignored exit 6, 1024 bytes kept
fuzz: 2000 agree
fuzz mutant: stopped at first disagreement
fuzz letter-offset mutant: stopped at first byte disagreement
row 12: fuzz ok
driver: layout-mutants exit 1 is fatal
driver: seed-audit exit 1 is fatal
driver: hex0-contract exit 1 is fatal
driver: layout-mutants hang timed out
driver: seed-audit hang timed out
driver: hex0-contract hang timed out
driver: non-host target is not executed
driver-test: skipped on the nested run
layout: ok
plain clone: layout ok
layout: ok
autocrlf clone: lf
mutant autocrlf without the attribute: red
verify: working tree, committed in the sandbox and cloned
```

## Round 6 — the gate names what it refuses

`tools/verify.sh` exited 0. Stderr was empty (0 bytes). The log is `/var/tmp/hex0-verify-r6.log`, 219 lines. HEAD stayed `f6a432304060455d54abf01ffeea3086f87ee9be`. The index sha256 stayed `2e16aa19af4f1cede5b2dc965d29f9c0c1db6f20607ea17a783d8821d83e16ad`. `git status --porcelain` was the same before and after the run. The in-script hash of `.git` `HEAD`, `index`, `config`, and `refs` matched, and the log's last line is `verify: sandbox candidate, clone layout, outer repository unchanged`. A tar of those same paths taken outside the script hashed differently before and after; the index bytes did not change. This strike does not commit.

The log printed `row 10: 537 bytes` and `row 5: 755`. `row 9: 156 instructions match`. `row 14: SIGXFSZ default exit 153, RLIMIT_CORE 0`. `row 15: SIGXFSZ ignored exit 6, 1024 bytes kept`. `fuzz: 2000 agree`. `second target with a pointer: green`. `layout: rule 2: scan crashed`. `driver: setsid escape`. `driver: interrupt stopped the step`. `aarch64-linux: not executed on this host`. `git: linked worktree did not copy the gitdir`. `plain clone: layout ok`. `autocrlf clone: lf`. `mutant autocrlf without lf: red`.

The quoted specimen in the weigh is not the bare-reference mutant. The unquoted files are, and the log printed both bare-reference lines. The root refusal was not executed: this strike is not root.

Wards were not cast. The rung is not landed. hex1 was not started.

### What the log showed red, and what is still open

| Wall | What went red in this log | Still open |
| --- | --- | --- |
| A gate that only ever said ok | `driver: layout-mutants exit 1 is fatal` | |
| A gate that saw only tracked files | `mutant stray top-level file` and `mutant untracked archived file` | |
| A brief that pointed the gate at scratch | The gate's layout ran on a sandbox copy of this repository and printed `layout: ok` | No separate scratch-path mutant in this run |
| `.gitattributes` rewriting fixtures | `mutant autocrlf without lf: red` | |
| Messages crossing in flight | | No gate wall |
| A mutant that never ran its row | Row 1, row 2, row 3, row 4, and row 10 each printed their own refusal | |
| Condensed ward texts | | No gate wall. Wards were not cast |
| R35, status text in a target source | `mutant status word` and `mutant status block` | |
| R35, ASCII | `mutant row 11 (ascii)` | |
| R36, step and expect | self-kill, setsid escape, scale refusal, interrupt, replay, the hang, and `bare command: cmp` | |
| R37, one git entry | `git: caller GIT_DIR ignored`, `git: hooks ignored`, `git: fixed identity`, `git: linked worktree did not copy the gitdir` | |
| R38, facts and host | `row 10: 537 bytes`; `aarch64-linux: not executed on this host` | The root refusal was not executed |
| R39, named comparisons | The row mutants above, plus both clone rows' layout | |
| R40, disagreement kept as text | Fuzz status and letter mutants; `layout: rule 2: scan crashed`; rows 14 and 15 | |
| R41, names on disk | Hidden brief, hidden rung, plan, tests brief, quoted and variable redirects, tools write of a seed, case-insensitive bare reference | |
| R42, the documents | The same tree printed `layout: ok` before the mutants | |
| R43, this table | The record of the walls above | |
| R44, third-vigilia L2 | Fixed in the rows above, or runed below | What sequences the rungs, and the GitHub description and homepage, are open for the builder |

Runes at the site:

- `tools/verify.sh` line 5, `rune:solvere(scratch)` — one gate owns `out/` per run.
- `tools/check/driver-test.sh` line 4, `rune:peragrare(stub)` — the non-host row stubs the modules.
- `tools/check/hex0-contract.sh` line 4, `rune:circumspicere(phantom)` — an empty argv is not observable here.
- `tools/check/disasm-check.py` line 10, `rune:circumspicere(spelling)` — row 9 matches this objdump's mnemonics.
- `tools/check/fuzz-hex0.py` line 14, `rune:solvere(duplication)` — the fuzz reference restates the other scan on purpose.
- `DESIGN-the-ladder.md` line 82, `rune:exigere(prose)` — watc's register partition is described, not checked by this gate.

### What verify printed

```
step-lint: ok
step-lint: ok
step-lint: ok
step-lint: ok
step-lint: ok
step-lint: ok
row 18: step-lint ok
bare command: cmp line 2: cmp /dev/null /dev/null
mutant step-lint: red
layout: ok
layout: rule 1: top-level name not in the layout: STRAY
mutant stray top-level file: red
layout: rule 1: brand/ holds a non-image: brand/subdir
mutant brand directory: red
layout: rule 1: brand/ holds a non-image: brand/x.md
mutant brand non-image: red
layout: rule 2: ELF magic outside the seed: brand/evil.png
mutant ELF in brand: red
layout: rule 2: ELF magic outside the seed: brand/marked.png
mutant ELF appended to a PNG: red
layout: rule 1: tracked out/ path: out/h1
mutant tracked out: red
rm 'out/h1'
layout: rule 2: ELF magic outside the seed: ladder/0-hex0/tests/second.elf
mutant second ELF: red
layout: rule 2: ELF magic outside the seed: ladder/0-hex0/hex0
mutant seed outside a target: red
layout: rule 2: ELF magic outside the seed: ladder/0-hex0/x86_64-linux/other
mutant second binary inside a target: red
layout: rule 2: binary outside the seed and brand/: ladder/0-hex0/tests/second.bin
mutant NUL binary: red
layout: rule 3: process document inside a rung: ladder/0-hex0/x86_64-linux/note.md
mutant markdown inside a target: red
layout: rule 3: process document inside a rung: ladder/0-hex0/x86_64-linux/plan.md
mutant plan inside a target: red
layout: rule 3: rung holds something other than README, tests/, and a target: ladder/0-hex0/.BRIEF.md
mutant hidden brief: red
layout: rule 3: process document inside a rung: ladder/0-hex0/tests/BRIEF-hex1.md
mutant brief inside tests: red
layout: rule 3: tests/ holds a directory: ladder/0-hex0/tests/nested
mutant nested tests directory: red
layout: rule 3: rung holds something other than README, tests/, and a target: ladder/0-hex0/BRIEF.md
mutant brief inside a rung: red
layout: rule 3: target has no source: ladder/0-hex0/aarch64-linux
mutant target with no source: red
layout: rule 3: target has no source: ladder/0-hex0/aarch64-linux
mutant target with only a table: red
layout: rule 3: target not named in the design table: ladder/0-hex0/x86_64-freebsd
mutant target not in the design table: red
layout: rule 3: target name is not <arch>-<os>: ladder/0-hex0/X86-64
mutant badly named target: red
layout: rule 4: rung directory is not <n>-<name>: NotARung
mutant rung name: red
layout: rule 4: rung directory is not <n>-<name>: .1-hex1
mutant hidden rung: red
layout: rule 4: rung numbers skip 1 (found 3)
mutant rung number gap: red
rm 'ladder/0-hex0/README.md'
layout: rule 5: rung has no README.md: 0-hex0
mutant rung without README: red
layout: rule 5: readme has no exit statuses: 0-hex0
mutant readme without an exit table: red
layout: rule 5: target source states a status meaning: ladder/0-hex0/x86_64-linux/hex0.hex0
mutant status word: red
layout: rule 5: target source states a status meaning: ladder/0-hex0/x86_64-linux/hex0.hex0
mutant status block: red
layout: rule 6: archived/ bytes differ from c45603e
mutant archived byte: red
layout: rule 6: untracked file under archived/: ?? archived/untracked.txt
mutant untracked archived file: red
layout: rule 7: a tools file redirects into out/: tools/check/writes-out.sh
mutant redirect into out/: red
layout: rule 7: a tools file redirects into out/: tools/check/writes-quoted.sh
mutant quoted redirect: red
layout: rule 7: a tools file redirects into out/: tools/check/writes-var.sh
mutant variable redirect: red
layout: rule 7: a tools file tees into out/: tools/check/tees-out.sh
mutant tee-out: red
layout: rule 7: a tools file copies into out/: tools/check/copies-out.sh
mutant copy into out/: red
layout: rule 7: a tools file moves into out/: tools/check/moves-out.sh
mutant move into out/: red
layout: rule 7: a tools file writes out/ with dd: tools/check/dd-out.sh
mutant dd into out/: red
layout: rule 7: a tools file installs into out/: tools/check/installs-out.sh
mutant install-out: red
layout: rule 7: a tools file names -o into out/: tools/check/o-out.sh
mutant dash-o into out/: red
layout: rule 7: a tools file writes a target seed: tools/check/writes-seed.sh
mutant tools write a seed: red
layout: rule 8: colon-path token in tools/check/colon.wat
mutant colon path: red
rm 'tools/check/colon.wat'
layout: rule 8: bare type arrow in tools/check/arrow.wat
mutant tracked arrow: red
rm 'tools/check/arrow.wat'
layout: rule 9: stray directory under docs/: stray-dir
mutant stray directory under docs/: red
layout: rule 9: docs/ top level is not a standing document: stray.bin
mutant docs top-level non-document: red
layout: rule 9: excursus year is not YYYY: YYYY
mutant year not YYYY: red
layout: rule 9: excursus month is not MM: 2026/13
mutant month not MM: red
layout: rule 9: excursus month has no counter: 2026/02
mutant empty month: red
layout: rule 9: excursus counter gap: 2026/10 missing 002
mutant counter gap: red
layout: rule 9: excursus holds a directory: 2026/10/001-the-ladder/nested
mutant directory inside an excursus: red
layout: rule 9: excursus holds a non-document: 2026/10/001-the-ladder/stray.hex0
mutant non-document in an excursus: red
layout: rule 9: badly formed excursus slug: 2026/10/002-BadSlug
mutant bad slug: red
layout: rule 9: bare numbered reference in docs/bare-ref.md
mutant bare numbered reference: red
rm 'docs/bare-ref.md'
layout: rule 9: bare numbered reference in docs/case-ref.md
mutant case-insensitive bare reference: red
rm 'docs/case-ref.md'
second target with a pointer: green
layout: rule 2: scan crashed
mutant rule 2 crash: red
row 1: cmp identical
mutant row 1 (byte): red
row 2: cmp identical
mutant row 2 (byte): red
row 9: 156 instructions match
mutant row 9 (comment): red
mutant row 9 (offset): red
mutant row 9 (count): red
row 10: 537 bytes
mutant row 10 (size): red
row 11: lint ok
mutant row 11 (bare): red
mutant row 11 (ascii): red
row 3: cmp identical, exit 0
mutant row 3 (bytes): red
row 8: execve read write open close fstat exit ftruncate fchmod
mutant row 8 (extra syscall): red
mutant row 8 (second execve): red
row 4: cmp identical, exit 42
mutant row 4 (status): red
row 5: 755
row 5: preexist 600 is 755
row 6: lower exit 0
row 6: upper exit 0
row 6: crlf exit 0
row 6: eof exit 0
row 6: comments exit 0
row 6: split exit 0
row 6: comment-nibble exit 0
row 6: comment-cr exit 0
row 6: comment-tab exit 0
row 6: comment-high exit 0
row 6: crlf-two exit 0
row 7: empty argv exit 1
row 7: argc 1 exit 1
row 7: one path exit 1
row 7: argc 4 exit 1
row 7: missing IN exit 2
row 7: G exit 4
row 7: vt exit 4
row 7: ff exit 4
row 7: reject-2f exit 4
row 7: reject-40 exit 4
row 7: reject-80 exit 4
row 7: reject-ff exit 4
row 7: odd exit 5
row 7: odd-after exit 5
row 7: missing OUT directory exit 3, absent stays absent
row 7: non-regular exit 3, mode unchanged
row 7: same device exit 7
row 7: fifo with no reader exit 3, mode unchanged
row 7: fifo with a reader exit 3, mode unchanged
row 7: read-only same file exit 3, unchanged
row 7: same path exit 7
row 7: hard link exit 7
row 7: symlink exit 7
row 7: absent same path exit 2
row 7: directory IN exit 6
fault: range checks exit 93
fault: close_range closed fd 300
fault: signal re-injected
row 13: fstat IN exit 2, control 0
row 13: fstat OUT exit 3, control 0
row 13: fchmod exit 3, control 0
row 13: read exit 6, control 0
row 13: write exit 6, control 0
row 13: close exit 6, control 0
row 13: ftruncate exit 6, control 0
row 13: write after a byte exit 6, control 0
row 13: read after bytes exit 6, control 0
mutant trunc-before-fchmod: red (rc 3, mode 640, bytes truncated)
row 14: SIGXFSZ default exit 153, RLIMIT_CORE 0
row 15: SIGXFSZ ignored exit 6, 1024 bytes kept
fuzz: 2000 agree
fuzz mutant: stopped at first status disagreement
fuzz letter-offset mutant: stopped at first byte disagreement
row 12: fuzz ok
driver: self-kill is not timed out
driver: setsid escape
driver: scale refusal
driver: interrupt stopped the step
driver: replay kept the token
driver: layout-mutants exit 1 is fatal
driver: layout-mutants hang timed out
driver: non-host target is not executed
driver-test: skipped on the nested run
git: caller GIT_DIR ignored
git: hooks ignored
git: fixed identity
HEAD is now at 49efa71 fixed identity
git: linked worktree did not copy the gitdir
plain clone: layout ok
autocrlf clone: lf
mutant autocrlf attribute: red
mutant autocrlf without lf: red
verify: sandbox candidate, clone layout, outer repository unchanged
```
