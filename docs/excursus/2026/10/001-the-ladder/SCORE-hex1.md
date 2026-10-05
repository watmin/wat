# SCORE — hex1

Milestone 4, the self-weigh of the hex1 rows, is recorded below. Hex2's first increment and its self-weigh are at the end. Long names and the absolute address stay asked. Not landed. The seed is unchanged.

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
