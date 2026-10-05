# SCORE — hex1

Milestone 4, the self-weigh of the hex1 rows, is recorded below. Hex2 is weighed. The M0 self-weigh is recorded below. wat0's builtin table is at the end. Not landed. The seed is unchanged.

## Milestone 1 — the contract is in the tree, and the gate is red (2026-10-04)

`tools/verify` exited 1. Stderr was:

```
verify: row 28 bad-g.hex0
verify: status None exists False mode None timed_out False escaped ()
```

Stdout was 29 lines. The last line was `row 27: tree unchanged`. The line `verify: judged, outer repository unchanged` did not print. `python3`'s `time.perf_counter` around that one process read 11.079946317 seconds. `/usr/bin/time` is not on this machine, so that is the clock. The log is `/var/tmp/hex1-verify-m1.log`, and the stderr is `/var/tmp/hex1-verify-m1.err`.

```
row 0: prover refuses an always-accept judge
row 1: hex-check identical
row 2: sed|xxd identical
row 3: fixpoint
row 4: exit 42
row 5: 755
row 6: formats
row 7: refusals
row 8: syscalls
row 9: 156 instructions
row 10: 537 bytes
row 11: lint
row 12: fuzz 2000
row 13: faults
row 14: SIGXFSZ default
row 15: SIGXFSZ ignored
row 16: capability 7
row 17: empty argv
row 18: fd 300
row 19: sha256
row 20: layout
layout mutants: red
row 21: outer repository unchanged
row 22: clone
row 23: hostile startup is red
row 24: signals
row 25: out/ lock
row 26: ast lint
row 27: tree unchanged
```

Row 28 runs every file in `ladder/0-hex0/tests/` through the seed and through `out/hex1`, and `Expect` asks for the seed's status, bytes, and mode. `out/hex1` is not a file. The row records that and does not exec the missing path. `bad-g.hex0` is the first name. The rows after it are in `tools/gate/hex1rows.py` and did not run.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## Asked of the builder

- Status 10, and the most negative and most positive signed-32 displacements. The gap is about 2^31 output bytes. No committed fixture of that size is in `tests/`. How should the gate produce that input?
- Statuses 8, 9, and 11 are judged by status only, on an absent OUT and on an existing OUT. The bytes and the mode left in OUT are not judged. The handoff does not say what those files hold.

## Milestones 2 and 3 — hex1 builds, and every row is green (2026-10-04)

`./build` exited 0. It ran the seed on `ladder/1-hex1/x86_64-linux/hex1.hex0` and wrote `out/hex1`, then ran that program on `ladder/1-hex1/x86_64-linux/hex1.hex1` and wrote `out/hex1-self`. Both files are 981 bytes, mode 755. `gate.tsv` names `size` 981, `code_base` 120, and `lseek_nth` 1.

`tools/verify` exited 0. Stderr was empty. Stdout was 39 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 8.428123052 seconds. `/usr/bin/time` is not on this machine, so that is the clock. The log is `/var/tmp/hex1-verify-m2.log`, and the stderr is `/var/tmp/hex1-verify-m2.err`.

```
row 0: prover refuses an always-accept judge
row 1: hex-check identical
row 2: sed|xxd identical
row 3: fixpoint
row 4: exit 42
row 5: 755
row 6: formats
row 7: refusals
row 8: syscalls
row 9: 156 instructions
row 10: 537 bytes
row 11: lint
row 12: fuzz 2000
row 13: faults
row 14: SIGXFSZ default
row 15: SIGXFSZ ignored
row 16: capability 7
row 17: empty argv
row 18: fd 300
row 19: sha256
row 20: layout
layout mutants: red
row 21: outer repository unchanged
row 22: clone
row 23: hostile startup is red
row 24: signals
row 25: out/ lock
row 26: ast lint
row 27: tree unchanged
row 28: hex1 parity
row 29: labels
row 30: bad label
row 31: refusals
row 32: self-build
row 33: syscalls
row 34: disasm
row 35: size
row 36: lseek fault
verify: judged, outer repository unchanged
```

Row 28 is the row that was red in milestone 1. It was red because `out/hex1` was not a file: status None, exists False. The seed's rows 0–27 had already printed. This run built the program first, and row 28 printed `row 28: hex1 parity`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

The two questions above are still open. Status 10 has no fixture, and the label row does not cover a displacement at either end of signed 32 bits. Milestone 4, the self-weigh of the hex1 rows, is not in this section.

## The bounds and the residue (2026-10-04)

The two questions in "Asked of the builder" are answered in `ladder/1-hex1/README.md`. An accepted displacement runs from −2147483648 through 2147483647. An output shorter than 2147483648 bytes reaches neither end and does not reach status 10. The gate does not run that status. fchmod and ftruncate run before either pass. Status 9 and status 11 leave OUT empty, mode 0755. Status 8 leaves the bytes pass 2 has already written, mode 0755. `undef-after.hex1` is the byte `41` and then an undefined reference, and OUT holds that one byte.

`tools/verify` exited 0. Stderr was empty. Stdout was 39 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 10.972573506 seconds. `/usr/bin/time` is not on this machine, so that is the clock. The log is `/var/tmp/hex1-verify-residue.log`, and the stderr is `/var/tmp/hex1-verify-residue.err`.

```
row 0: prover refuses an always-accept judge
row 1: hex-check identical
row 2: sed|xxd identical
row 3: fixpoint
row 4: exit 42
row 5: 755
row 6: formats
row 7: refusals
row 8: syscalls
row 9: 156 instructions
row 10: 537 bytes
row 11: lint
row 12: fuzz 2000
row 13: faults
row 14: SIGXFSZ default
row 15: SIGXFSZ ignored
row 16: capability 7
row 17: empty argv
row 18: fd 300
row 19: sha256
row 20: layout
layout mutants: red
row 21: outer repository unchanged
row 22: clone
row 23: hostile startup is red
row 24: signals
row 25: out/ lock
row 26: ast lint
row 27: tree unchanged
row 28: hex1 parity
row 29: labels
row 30: bad label
row 31: refusals
row 32: self-build
row 33: syscalls
row 34: disasm
row 35: size
row 36: lseek fault
verify: judged, outer repository unchanged
```

Row 31 is the row that now judges the bytes and the mode. The program was not rebuilt for this run. `out/hex1` was the file `./build` wrote for milestones 2 and 3.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

Milestone 4, the self-weigh of the hex1 rows, is the next section.

## Milestone 4 — self-weigh (2026-10-04)

The live `tools/verify` exited 0 in 10.923268756 seconds. Stderr was empty. Stdout was 39 lines. The last line was `verify: judged, outer repository unchanged`. The log is `/var/tmp/hex1-verify-weigh.log`. The sha256 of the sorted `.git` listing, 60 files, was `828f255ad8d5835165de3baef30e67ecc90a5620f9add574663ef257cdfb2f8d` before and after. The two listings are `/var/tmp/hex1-weigh-live-before.txt` and `/var/tmp/hex1-weigh-live-after.txt`, and they match. The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

Each broken run is a `cp -a` copy under `/var/tmp`. One comparison inside that row's judge was replaced with `False` for that row's reason. Earlier rows still judged. The function was left in place.

| Row | Judge | Red line |
| --- | --- | --- |
| 28 parity | Expect | `verify: row 28 bad-g.hex0: mutant status stayed green` |
| 29 labels | Expect | `verify: row 29 forward.hex1: mutant status stayed green` |
| 30 bad label | Expect | `verify: row 30 label-digit.hex1: mutant status stayed green` |
| 31 refusals | Expect | `verify: row 31 undef.hex1: mutant status stayed green` |
| 32 self-build | SameHash | `verify: row 32 self: mutant changed stayed green` |
| 33 syscalls | Hex1Calls | `verify: row 33 syscalls: mutant extra stayed green` |
| 34 disasm | CommentDisasm | `verify: row 34 disasm: mutant offset stayed green` |
| 36 lseek | Expect | `verify: row 36 lseek absent: mutant status stayed green` |

Row 35 went green on the first copy. Replacing `obs.length != self.want` with `False` left `tools/verify` at exit 0 in 9.751853905 seconds, stderr empty, last line `verify: judged, outer repository unchanged`. The length mutant still failed `filesz != length` and `memsz != length`. The second copy replaced all three comparisons with `False`. That gate exited 1 in 8.718610250 seconds. Stderr's first line was `verify: row 35 size: mutant length stayed green`. Stdout's last line was `row 34: disasm`.

Stale index, no `git status` before the gate: exit 0 in 10.756403769 seconds, stderr empty, last line `verify: judged, outer repository unchanged`. The copy's `.git` listing stayed `828f255ad8d5835165de3baef30e67ecc90a5620f9add574663ef257cdfb2f8d` (60 files). After `git ls-files` and `touch` of every tracked file, the same listing was unchanged and the gate exited 0 in 10.143844255 seconds, stderr empty, same last line, same `.git` listing.

Adding `def row_weigh_static` with `_static(0 if a == b else 1)` to a copy made the gate exit 1 in 9.037892642 seconds. Stderr was `verify: row 26 ast`. Stdout was 27 lines and ended at `row 25: out/ lock`.

## Hex2 — the rung directory (2026-10-04)

`ladder/2-hex2/README.md` is the contract. Hex2 accepts hex1's language and is the rung for an 8-bit relative, a 16-bit relative, an absolute address, and a label longer than one byte. The spelling of each form is unruled. No fixture and no target source are in the tree. `build` does not run this rung. Statuses 0–11 stay hex1's. A number past 11 is unruled.

`tools/verify` exited 0. Stderr was empty. Stdout was 39 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 11.598681197 seconds. The log is `/var/tmp/hex2-verify-files.log`, and the stderr is `/var/tmp/hex2-verify-files.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## Hex2 — `%1` and `%2` (2026-10-04)

This increment is hex1 plus two relatives. `%` stays the 4-byte field. `%1` is one signed byte, from −128 through 127. `%2` is two signed bytes, from −32768 through 32767. Any other digit after `%` is a bad byte. A displacement outside the field just opened is status 10. One-byte labels are unchanged. A longer name, and an absolute address, stay asked.

`./build` exited 0. `out/hex2` and `out/hex2-self` are 1154 bytes, mode 755. `gate.tsv` names `size` 1154.

`tools/verify` exited 0. Stderr was empty. Stdout was 47 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 14.290250287 seconds. The log is `/var/tmp/hex2-verify-inc.log`, and the stderr is `/var/tmp/hex2-verify-inc.err`.

```
row 0: prover refuses an always-accept judge
row 1: hex-check identical
row 2: sed|xxd identical
row 3: fixpoint
row 4: exit 42
row 5: 755
row 6: formats
row 7: refusals
row 8: syscalls
row 9: 156 instructions
row 10: 537 bytes
row 11: lint
row 12: fuzz 2000
row 13: faults
row 14: SIGXFSZ default
row 15: SIGXFSZ ignored
row 16: capability 7
row 17: empty argv
row 18: fd 300
row 19: sha256
row 20: layout
layout mutants: red
row 21: outer repository unchanged
row 22: clone
row 23: hostile startup is red
row 24: signals
row 25: out/ lock
row 26: ast lint
row 27: tree unchanged
row 28: hex1 parity
row 29: labels
row 30: bad label
row 31: refusals
row 32: self-build
row 33: syscalls
row 34: disasm
row 35: size
row 36: lseek fault
row 37: hex2 parity
row 38: widths
row 39: bad width
row 40: self-build
row 41: syscalls
row 42: disasm
row 43: size
row 44: lseek fault
verify: judged, outer repository unchanged
```

Row 37 matched hex2 against hex1 on every hex0 fixture and every hex1 fixture. Row 38 ran the one-byte ends from `tests/` and the two-byte ends from an input the row wrote: a backward displacement of −32768, and one past it at status 10. Row 40 is `out/hex2` and `out/hex2-self` hashing equal.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## Hex2 — self-weigh (2026-10-04)

The live `tools/verify` exited 0 in 14.391374263 seconds. Stderr was empty. Stdout was 47 lines. The last line was `verify: judged, outer repository unchanged`. The log is `/var/tmp/hex2-verify-weigh.log`. The sha256 of the sorted `.git` listing, 116 files, was `dcab1aec1e7b88dd35d7c35d13c7de8f9abffee667a7e867d439784b79dab056` before and after. The two listings are `/var/tmp/hex2-weigh-live-before.txt` and `/var/tmp/hex2-weigh-live-after.txt`, and they match. The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

Each broken run is a `cp -a` copy under `/var/tmp`. One comparison inside that row's judge was replaced with `False` for that row's reason. Earlier rows still judged. The function was left in place.

| Row | Judge | Red line |
| --- | --- | --- |
| 37 parity | Expect | `verify: row 37 bad-g.hex0: mutant status stayed green` |
| 38 widths | Expect | `verify: row 38 rel1-zero.hex2: mutant status stayed green` |
| 39 bad width | Expect | `verify: row 39 bad-width-0.hex2: mutant status stayed green` |
| 40 self-build | SameHash | `verify: row 40 self: mutant changed stayed green` |
| 41 syscalls | Hex2Calls | `verify: row 41 syscalls: mutant extra stayed green` |
| 42 disasm | CommentDisasm | `verify: row 42 disasm: mutant offset stayed green` |
| 44 lseek | Expect | `verify: row 44 lseek absent: mutant status stayed green` |

Row 43 went green on the first copy. Replacing `obs.length != self.want` with `False` left `tools/verify` at exit 0 in 13.312021127 seconds, stderr empty, last line `verify: judged, outer repository unchanged`. The length mutant still failed `filesz != length` and `memsz != length`. The second copy replaced all three comparisons with `False`. That gate exited 1 in 11.760067749 seconds. Stderr's first line was `verify: row 43 size: mutant length stayed green`. Stdout's last line was `row 42: disasm`.

Stale index, no `git status` before the gate: exit 0 in 13.848416230 seconds, stderr empty, last line `verify: judged, outer repository unchanged`. The copy's `.git` listing stayed `dcab1aec1e7b88dd35d7c35d13c7de8f9abffee667a7e867d439784b79dab056` (116 files). After `git ls-files` and `touch` of every tracked file, the same listing was unchanged and the gate exited 0 in 14.256461908 seconds, stderr empty, same last line, same `.git` listing.

Adding `def row_weigh_static` with `_static(0 if a == b else 1)` to a copy made the gate exit 1 in 9.441402897 seconds. Stderr was `verify: row 26 ast`. Stdout was 27 lines and ended at `row 25: out/ lock`.

## Hex2 — `&` (2026-10-04)

`&` followed by a label emits the virtual address: the file offset plus `0x400000`, four unsigned bytes, little-endian. A sum that does not fit in four bytes is status 10. An output shorter than 4290772992 bytes does not reach that refusal, so the gate does not run it. `&` remains a legal label name. A longer name stays asked.

`hex2.hex2` writes the low 4 bytes of `e_entry` as `&~`, the label on the first instruction. The high 4 bytes stay zero. That is file offset `0x78` plus the load address, the bytes `78 00 40 00`.

`./build` exited 0. `out/hex2` and `out/hex2-self` are 1238 bytes, mode 755. `gate.tsv` names `size` 1238.

`tools/verify` exited 0. Stderr was empty. Stdout was 47 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 12.957846675 seconds. The log is `/var/tmp/hex2-verify-abs.log`, and the stderr is `/var/tmp/hex2-verify-abs.err`. Rows 37 through 44 printed, and row 38 now includes `abs-four.hex2`, `abs-base.hex2`, `abs-undef.hex2`, and `label-amp.hex2`. Row 39 includes `bad-amp.hex2`. The judge for those rows is the one the self-weigh already broke.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## Hex2 — self-weigh after `&` (2026-10-04)

The live `tools/verify` exited 0 in 14.661466060 seconds. Stderr was empty. Stdout was 47 lines. The last line was `verify: judged, outer repository unchanged`. The log is `/var/tmp/hex2-verify-weigh-amp.log`. The sha256 of the sorted `.git` listing, 148 files, was `77036cc794dc7a3d25f3cc22ac20fc40ae33bd2ab97eb320214beae4d43ec51a` before and after. The two listings are `/var/tmp/hex2-weigh-amp-before.txt` and `/var/tmp/hex2-weigh-amp-after.txt`, and they match. The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

Each broken run is a `cp -a` copy under `/var/tmp`. One comparison inside that row's judge was replaced with `False` for that row's reason. Earlier rows still judged. The function was left in place.

| Row | Judge | Red line |
| --- | --- | --- |
| 37 parity | Expect | `verify: row 37 bad-g.hex0: mutant status stayed green` |
| 38 widths | Expect | `verify: row 38 rel1-zero.hex2: mutant status stayed green` |
| 38 absolute | Expect | `verify: row 38 abs-four.hex2: mutant status stayed green` |
| 39 bad width | Expect | `verify: row 39 bad-width-0.hex2: mutant status stayed green` |
| 39 ampersand | Expect | `verify: row 39 bad-amp.hex2: mutant status stayed green` |
| 40 self-build | SameHash | `verify: row 40 self: mutant changed stayed green` |
| 41 syscalls | Hex2Calls | `verify: row 41 syscalls: mutant extra stayed green` |
| 42 disasm | CommentDisasm | `verify: row 42 disasm: mutant offset stayed green` |
| 44 lseek | Expect | `verify: row 44 lseek absent: mutant status stayed green` |

The absolute row and the ampersand row are the same judges as 38 and 39, with the comparison replaced only for reasons that start with `row 38 abs` and `row 39 bad-amp`. The earlier fixtures in those rows still judged. `abs-four.hex2` is the output `04 00 40 00 41`.

Row 43 went green on the first copy. Replacing `obs.length != self.want` with `False` left `tools/verify` at exit 0 in 12.185172790 seconds, stderr empty, last line `verify: judged, outer repository unchanged`. The length mutant still failed `filesz != length` and `memsz != length`. The second copy replaced all three comparisons with `False`. That gate exited 1 in 11.769732237 seconds. Stderr's first line was `verify: row 43 size: mutant length stayed green`. Stdout's last line was `row 42: disasm`.

Stale index, no `git status` before the gate: exit 0 in 11.065043036 seconds, stderr empty, last line `verify: judged, outer repository unchanged`. The copy's `.git` listing stayed `77036cc794dc7a3d25f3cc22ac20fc40ae33bd2ab97eb320214beae4d43ec51a` (148 files). After `git ls-files` and `touch` of every tracked file, the same listing was unchanged and the gate exited 0 in 11.391638964 seconds, stderr empty, same last line, same `.git` listing.

Adding `def row_weigh_static` with `_static(0 if a == b else 1)` to a copy made the gate exit 1 in 7.917573759 seconds. Stderr was `verify: row 26 ast`. Stdout was 27 lines and ended at `row 25: out/ lock`.

## Hex2 — names end at whitespace (2026-10-04)

A name is the bytes after `:`, `%`, `%1`, `%2`, or `&`, and it ends at space, tab, CR, or LF. It may contain digits. A name of one byte at the end of a line is the hex1 label. `:G48` on one line is the name `G48`. `:G` and then `48` on the next line is label `G` and the byte `0x48`. A name is at most 16 bytes. The table holds 64 names. An empty name, a 17th byte, and a 65th name are bad bytes.

`name-glued.hex2` produces `41 FB FF FF FF`. `name-split.hex2` produces `48`. `name-word.hex2` is `:main`, then `%1main`, then `41`, and produces `FF 41`. `name-twice.hex2` exits 9. `name-undef.hex2` exits 8.

Seven hex1 fixtures are names now, so row 37 does not compare them. `41:0` is the byte `41` and the name `0`.

`./build` exited 0. `out/hex2` and `out/hex2-self` are 1486 bytes, mode 755. `gate.tsv` names `size` 1486.

`tools/verify` exited 0. Stderr was empty. Stdout was 47 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 13.308954403 seconds. The log is `/var/tmp/hex2-verify-names.log`, and the stderr is `/var/tmp/hex2-verify-names.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## Hex2 — self-weigh after names (2026-10-04)

The live `tools/verify` exited 0 in 13.973670689 seconds. Stderr was empty. Stdout was 47 lines. The last line was `verify: judged, outer repository unchanged`. The log is `/var/tmp/hex2-verify-weigh-names.log`. The sha256 of the sorted `.git` listing, 47 files, was `c73541a06112edbf9e4a70305be4fb3a4789236075107e5b203e405543955366` before and after. The two listings are `/var/tmp/hex2-weigh-names-before.txt` and `/var/tmp/hex2-weigh-names-after.txt`, and they match. The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

Each broken run is a `cp -a` copy under `/var/tmp`. One comparison inside that row's judge was replaced with `False` for that row's reason. Earlier rows still judged. The function was left in place.

| Row | Judge | Red line |
| --- | --- | --- |
| 37 parity | Expect | `verify: row 37 bad-g.hex0: mutant status stayed green` |
| 38 widths | Expect | `verify: row 38 rel1-zero.hex2: mutant status stayed green` |
| 38 names | Expect | `verify: row 38 name-glued.hex2: mutant status stayed green` |
| 39 bad width | Expect | `verify: row 39 bad-width-0.hex2: mutant status stayed green` |
| 39 empty name | Expect | `verify: row 39 bad-amp.hex2: mutant status stayed green` |
| 40 self-build | SameHash | `verify: row 40 self: mutant changed stayed green` |
| 41 syscalls | Hex2Calls | `verify: row 41 syscalls: mutant extra stayed green` |
| 42 disasm | CommentDisasm | `verify: row 42 disasm: mutant offset stayed green` |
| 44 lseek | Expect | `verify: row 44 lseek absent: mutant status stayed green` |

The names row is the widths judge, with the comparison replaced only for reasons that start with `row 38 name`. The earlier fixtures in that row still judged. `name-glued.hex2` is the output `41 FB FF FF FF`.

Row 43 went green on the first copy. Replacing `obs.length != self.want` with `False` left `tools/verify` at exit 0 in 14.247337927 seconds, stderr empty, last line `verify: judged, outer repository unchanged`. The length mutant still failed `filesz != length` and `memsz != length`. The second copy replaced all three comparisons with `False`. That gate exited 1 in 13.107572747 seconds. Stderr's first line was `verify: row 43 size: mutant length stayed green`. Stdout's last line was `row 42: disasm`.

Stale index, no `git status` before the gate: exit 0 in 12.127104329 seconds, stderr empty, last line `verify: judged, outer repository unchanged`. The copy's `.git` listing stayed `c73541a06112edbf9e4a70305be4fb3a4789236075107e5b203e405543955366` (47 files). After `git ls-files` and `touch` of every tracked file, the same listing was unchanged and the gate exited 0 in 12.402310387 seconds, stderr empty, same last line, same `.git` listing.

Adding `def row_weigh_static` with `_static(0 if a == b else 1)` to a copy made the gate exit 1 in 8.510040200 seconds. Stderr was `verify: row 26 ast`. Stdout was 27 lines and ended at `row 25: out/ lock`.

## M0 — the crawl and the contract shell (2026-10-04)

`docs/excursus/2026/10/001-the-ladder/CRAWL-M0.md` records the stage0 C prototype. It tokenizes on whitespace, treats `DEFINE` as a macro, and prints hex text. It links libc and always succeeds. `ladder/3-m0/README.md` is the contract shell. No source and no fixture are in the tree. `build` does not run this rung.

The crawl's recommendation, not a ruling: M0 writes hex2 text, and hex2 emits the binary. The keyword, the body, strings, immediates, the new statuses, and the filenames stay asked.

`tools/verify` exited 0. Stderr was empty. Stdout was 47 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 13.975783586 seconds. The log is `/var/tmp/m0-verify-docs.log`, and the stderr is `/var/tmp/m0-verify-docs.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## M0 — DEFINE writes hex2 text (2026-10-04)

M0 reads hex2's language plus `DEFINE` and writes hex2 text. Hex2 assembles that text. The program is syscalls only. It does not link libc. Bash, the top-level `build`, is still the sequencer. M0's brief is not this increment.

`DEFINE` is a name and one body token. The name is at most 16 bytes. The body is at most 64 bytes. The table holds 64 definitions. The input is read into 65536 bytes. A use before its `DEFINE` is copied through. A second `DEFINE` of the same name is status 9. A missing name or body, a name longer than 16 bytes, a body longer than 64 bytes, a 65th definition, and an input longer than 65536 bytes are status 4. Statuses 5, 8, 10, and 11 are not produced.

`plain.m0` is `41 42` and a newline. The text is `41`, a newline, `42`, and a newline. `define-ten.m0` defines `ten` as `0A` and uses it. The text is `0A` and a newline. `dup.m0` is status 9 and OUT is empty. `missing.m0` is status 4 and OUT is empty.

A quoted string, a decimal immediate, and expansion of a name inside another definition's body stay asked.

`./build` exited 0. `out/m0` and `out/m0-self` are 1033 bytes, mode 755. `gate.tsv` names `size` 1033.

The first `tools/verify` exited 1. Stderr was `verify: row 49 disasm`. Stdout was 50 lines and ended at `row 48: syscalls`. One source line held five instructions, so the comment bytes were the whole sequence. That line is now five lines. The bytes are the same. The log is `/var/tmp/m0-verify-build.log`, and the stderr is `/var/tmp/m0-verify-build.err`.

The second `tools/verify` exited 0. Stderr was empty. Stdout was 53 lines. The last line was `verify: judged, outer repository unchanged`. The new lines were `row 45: text`, `row 46: refusals`, `row 47: self-build`, `row 48: syscalls`, `row 49: disasm`, and `row 50: size`. `python3`'s `time.perf_counter` around that one process read 13.675320774 seconds. The log is `/var/tmp/m0-verify-build-2.log`, and the stderr is `/var/tmp/m0-verify-build-2.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## M0 — define is a list (2026-10-04)

A definition is `(define name ...)`. The name is the second word. The words until `)` are the body. `(` and `)` are tokens even when they touch the next word. M0 writes each body token on its own line, then hex2 assembles that text. `(define SYSCALL 0F 05)` writes `0F` and `05` on their own lines. The program is syscalls only. Bash is still the sequencer.

The stored body, counting a newline between tokens, is at most 64 bytes. A list that is not `(define name ...)`, a missing `)`, a nested `(`, and a stray `)` are status 4. A second definition of the same name is status 9. A use before its definition is copied through.

`define-ten.m0` is `(define ten 0A)` and then the name. `dup.m0` defines `ten` twice. `missing.m0` is `(define ten)` with no body.

A quoted string, a decimal immediate, and expansion of a name inside another definition's body stay asked.

`./build` exited 0. `out/m0` and `out/m0-self` are 1170 bytes, mode 755. `gate.tsv` names `size` 1170.

`tools/verify` exited 0. Stderr was empty. Stdout was 53 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 13.337234530 seconds. The log is `/var/tmp/m0-verify-list.log`, and the stderr is `/var/tmp/m0-verify-list.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## M0 — self-weigh of rows 45–50 (2026-10-04)

The live `tools/verify` exited 0 in 13.557300375 seconds. Stderr was empty. Stdout was 53 lines. The last line was `verify: judged, outer repository unchanged`. The log is `/var/tmp/m0-verify-weigh-list.log`. The sha256 of the sorted `.git` listing, 117 files, was `a2175a565d31c9f718bc2fb85ec3aca86dd37ae3620636d51692f3828eb429aa` before and after. The two listings are `/var/tmp/m0-weigh-list-before.txt` and `/var/tmp/m0-weigh-list-after.txt`, and they match. The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

Each broken run is a `cp -a` copy under `/var/tmp`. One comparison inside that row's judge was replaced with `False` for that row's reason. Earlier rows still judged. The function was left in place.

| Row | Judge | Red line |
| --- | --- | --- |
| 45 text | Expect | `verify: row 45 plain: mutant status stayed green` |
| 46 refusals | Expect | `verify: row 46 dup.m0: mutant status stayed green` |
| 47 self-build | SameHash | `verify: row 47 self: mutant changed stayed green` |
| 48 syscalls | M0Calls | `verify: row 48 syscalls: mutant extra stayed green` |
| 49 disasm | CommentDisasm | `verify: row 49 disasm: mutant offset stayed green` |

Row 50 went green on the first copy. Replacing `obs.length != self.want` with `False` left `tools/verify` at exit 0 in 12.540255313 seconds, stderr empty, last line `verify: judged, outer repository unchanged`. The length mutant still failed `filesz != length` and `memsz != length`. The second copy replaced all three comparisons with `False`. That gate exited 1 in 11.048815632 seconds. Stderr's first line was `verify: row 50 size: mutant length stayed green`. Stdout's last line was `row 49: disasm`.

Stale index, no `git status` before the gate: exit 0 in 15.359294079 seconds, stderr empty, last line `verify: judged, outer repository unchanged`. The copy's `.git` listing stayed `a2175a565d31c9f718bc2fb85ec3aca86dd37ae3620636d51692f3828eb429aa` (117 files). After `git ls-files` and `touch` of every tracked file, the same listing was unchanged and the gate exited 0 in 16.292990866 seconds, stderr empty, same last line, same `.git` listing.

Adding `def row_weigh_static` with `_static(0 if a == b else 1)` to a copy made the gate exit 1 in 9.185983315 seconds. Stderr was `verify: row 26 ast`. Stdout was 27 lines and ended at `row 25: out/ lock`.

## M0 — a name in a body expands (2026-10-04)

A body word that is already defined expands to that definition's body. A word that is not defined yet is copied through. A cycle, where a name expands back into the definition being read, is status 4. The output is still hex2 text.

`compose.m0` defines `SYSCALL` as `0F 05`, defines `EXIT` as `SYSCALL`, and uses `EXIT`. The text is `0F`, a newline, `05`, and a newline. `early.m0` uses `EXIT` before `SYSCALL` exists. The text is the word `SYSCALL` and a newline. `cycle.m0` defines `a` as `b` and `b` as `a`. The status is 4 and OUT is empty.

A quoted string and a decimal immediate stay asked.

`./build` exited 0. `out/m0` and `out/m0-self` are 1355 bytes, mode 755. `gate.tsv` names `size` 1355.

`tools/verify` exited 0. Stderr was empty. Stdout was 53 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 12.262961245 seconds. The log is `/var/tmp/m0-verify-expand.log`, and the stderr is `/var/tmp/m0-verify-expand.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## wat0 — the brief (2026-10-04)

`docs/excursus/2026/10/001-the-ladder/BRIEF-wat0.md` is the brief. wat0 interprets the subset the compiler is written in. Its source will be M0 lists, and hex2 will emit the binary. A self tail call is a loop. The heap is an arena or counts, chosen after SCORE records the peak resident memory of wat-rs's stage 0 compiling the compiler. The translation of the compiler's source is the step before wat0 runs it. The five dilemmas in `CRAWL-the-subset.md` stay asked, and the interpreter is not started while they are open. This file is not M0's brief. Bash remains the sequencer.

The rung directory is not created.

`tools/verify` exited 0. Stderr was empty. Stdout was 53 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 13.704269185 seconds. The log is `/var/tmp/wat0-verify-brief.log`, and the stderr is `/var/tmp/wat0-verify-brief.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## wat0 — value spellings (2026-10-04)

The builder ruled the value spellings. An enum requires `wat.enum/Pure`. Variants are names, built from a map: `(wat.core/Option.Some {:value 42})`. A record is built from a map. One field is `(u/SomeRec/some-field r)`. Several fields bind with `{:keys [some-field another-field]}` in a `wat.core/let`. The bytes namespace is `wat.bytes/`. Uppercase names are a convention.

The operation names are proposed in `BRIEF-wat0.md` and are not ruled. The interpreter is not started.

`tools/verify` exited 0. Stderr was empty. Stdout was 53 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 12.525458143 seconds. The log is `/var/tmp/wat0-verify-spellings.log`, and the stderr is `/var/tmp/wat0-verify-spellings.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## wat0 — starting operation names (2026-10-05)

The builder accepted the operation table in `BRIEF-wat0.md` as the starting spellings. They can change as the language matures. A change is written in the brief before the interpreter grows a second spelling. `wat.io/read-file` stays the read that returns a string. The interpreter is not started. The heap measurement is still not in SCORE.

`tools/verify` exited 0. Stderr was empty. Stdout was 53 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 13.106334022 seconds. The log is `/var/tmp/wat0-verify-ops.log`, and the stderr is `/var/tmp/wat0-verify-ops.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## wat0 — the ladder does not run wat-rs (2026-10-05)

A wat-rs stage 0 run was started to measure peak memory and was stopped. No number was recorded. The builder ruled that the ladder does not run wat-rs. wat-rs is not a rung.

`BRIEF-wat0.md` now gives wat0 an arena that never frees. The gate is wat0's own fixpoint: wat0 writes a native compiler, and that compiler, run on its own source, writes a byte-identical compiler. The translation still turns the retired spelling into the spelling wat0 runs. The interpreter is not started.

`tools/verify` exited 0. Stderr was empty. Stdout was 53 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 13.834822683 seconds. The log is `/var/tmp/wat0-verify-nowatrs.log`, and the stderr is `/var/tmp/wat0-verify-nowatrs.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## wat0 — the first program (2026-10-05)

`ladder/4-wat0/tests/forty-two.wat` binds `x` to 40 and adds 2. wat0 writes `42` and a newline. `seven.wat` is the literal 7. `bad.wat` has no body: status 4, OUT empty. `dup.wat` defines `u/main` twice: status 9, OUT empty.

wat0 is M0 source. Hex2 emits the binary. The heap is an arena that never frees. This increment reads `wat.core/defn`, an empty parameter list, an optional `:-` and a type name, one body expression, integer literals, names, `wat.core/let`, and `wat.core/+`. Records, enums, `match`, parameters, and the rest of the operation table stay asked.

`./build` exited 0. `out/wat0` and `out/wat0-self` are 2034 bytes, mode 755. `gate.tsv` names `size` 2034.

`tools/verify` exited 0. Stderr was empty. Stdout was 59 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 10.668003135 seconds. The log is `/var/tmp/wat0-verify-first.log`, and the stderr is `/var/tmp/wat0-verify-first.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## wat0 — user/main (2026-10-05)

The builder ruled the entry. A program defines `user/main` with the signature `[] :- wat.type/nil`. wat0 invokes it. The result is nil. The line a person sees comes from `wat.kernel/println`.

A defined name may use any namespace except `wat` and `wat.*`. `user/helper` is definable. wat may later claim another `user/*` name as a rendezvous.

`forty-two.wat` prints `42`. `seven.wat` prints `7`. `helper.wat` defines `user/helper` and prints `42` from `user/main`. `bad.wat` is status 4. `watns.wat` defines `wat.core/nope` and is status 4. `dup.wat` defines `user/main` twice and is status 9.

`./build` exited 0. `out/wat0` and `out/wat0-self` are 2654 bytes, mode 755. `gate.tsv` names `size` 2654.

`tools/verify` exited 0. Stderr was empty. Stdout was 59 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 13.273060249 seconds. The log is `/var/tmp/wat0-verify-entry.log`, and the stderr is `/var/tmp/wat0-verify-entry.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.

## wat0 — builtin table (2026-10-05)

The built-in names are a table after the code. A row is the length, the name's bytes, a class, and the address of its code. Class 1 is an expression. Class 2 is a top-level form. The rows are `wat.core/defn`, `wat.core/+`, `wat.core/let`, and `wat.kernel/println`. A new built-in is a row plus the code it names.

`./build` exited 0. `out/wat0` and `out/wat0-self` are 2165 bytes, mode 755. `gate.tsv` names `code_end` 2071 and `size` 2165. The disassembly check stops at `code_end`. The table is data.

`tools/verify` exited 0. Stderr was empty. Stdout was 59 lines. The last line was `verify: judged, outer repository unchanged`. `python3`'s `time.perf_counter` around that one process read 14.773556987 seconds. The log is `/var/tmp/wat0-verify-table.log`, and the stderr is `/var/tmp/wat0-verify-table.err`.

The seed at the run was `ladder/0-hex0/x86_64-linux/hex0`, 537 bytes, mode 755, sha256 `572f8ef350f98507fee94fdbc50a1dcfd25758debda24d036efab069e808ae72`.
