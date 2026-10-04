# SCORE — hex1

Milestone 1 of HANDOFF-grok, Step 2. Not landed. The program is not written: there is no `out/hex1`, no `hex1.hex0`, and no `hex1.hex1`. The seed is unchanged.

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
