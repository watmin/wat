# EXPECTATIONS — rung 0: hex0

Amended through round 7. Every row is a line the gate prints. `tools/verify` takes no argument. Its last line, when the run is green, is `verify: judged, outer repository unchanged`. `--layout-only` checks `docs/LAYOUT.md` and prints `layout: ok`. An unknown argument is refused. There is one tier.

| # | what the gate prints | what it holds |
|---|---|---|
| 0 | `row 0: prover refuses an always-accept judge` | an always-accept judge, fed through the same prove loop, is red, and a judge with no mutant is red |
| 1 | `row 1: hex-check identical` | `hex-check.py` decodes the source to the seed |
| 2 | `row 2: sed\|xxd identical` | `sed` then `xxd` decode the source to the seed |
| 3 | `row 3: fixpoint` | the seed reads its source and writes itself, mode 0755 |
| 4 | `row 4: exit 42` | `tests/exit42.hex0` decodes to the bytes that exit 42 |
| 5 | `row 5: 755` | an OUT that already exists at mode 0600 becomes 0755 |
| 6 | `row 6: formats` | every format fixture decodes to its bytes, mode 0755 |
| 7 | `row 7: refusals` | every refusal, on an absent OUT and on an existing OUT, plus a missing directory, argc, `/dev/null`, both FIFO cases, the same path, a hard link, a symlink, a directory IN, and the read-only file. The plain read-only row refuses while `CAP_DAC_OVERRIDE` is effective |
| 8 | `row 8: syscalls` | exactly one `execve`, and it is the first traced call; every other name is in `syscalls.tsv` |
| 9 | `row 9: 156 instructions` | every instruction comment matches objdump. The machine, the code base and `--insn-width` come from `gate.tsv` |
| 10 | `row 10:` the byte count | the file length, `p_filesz` and `p_memsz` each match, and each comparison has a mutant |
| 11 | `row 11: lint` | every code line has a comment, and the source is ASCII |
| 12 | `row 12: fuzz` and the case count | 2000 cases, boundary bytes first, seed `20261004`. The reference, hex-check and the seed agree. A disagreement prints the input |
| 13 | `row 13: faults` | each forced call, on an absent OUT and an existing OUT, then a control. Out-of-range arguments exit 93. A real signal is re-injected. Nth means one call |
| 14 | `row 14: SIGXFSZ default` | shell status 153, and the child inherited `RLIMIT_CORE` 0 |
| 15 | `row 15: SIGXFSZ ignored` | status 6, and 1024 bytes kept |
| 16 | `row 16: capability 7` | under `unshare -U` with the capability effective, the read-only same file exits 7 and is unchanged |
| 17 | `row 17: empty argv` | argc 0, written at the exec stop, exits 1 |
| 18 | `row 18: fd 300` | the soft `NOFILE` limit is about 301. `close_range` closes fd 300 |
| 19 | `row 19: sha256` | the seed's sha256 is the one the rung README publishes |
| 20 | `row 20: layout` | `layout: ok`, and each rule's mutant is red on that rule's own needle |
| 21 | `row 21: outer repository unchanged` | every file under the real git dir and the common dir hashes the same. A new ref is red, and so is a write to `info/exclude`, with a directory `.git` and with a gitfile |
| 22 | `row 22: clone` | the clone's own `tools/verify --layout-only` prints `layout: ok`, and every text file is free of CR. A `*.py text eol=crlf` attribute is red, and so is a deleted `tests/* -text` line |
| 23 | `row 23: hostile startup is red` | a nested gate with `BASH_ENV`, `PYTHONPATH` and a user-site `.pth`, against a seed with one flipped byte, is red |
| 24 | `row 24: signals` | INT, TERM and HUP, each sent to a step's process group after a FIFO open, leave no descendant and no sandbox |
| 25 | `row 25: out/ lock` | a second gate prints `out/ is locked` and exits 1 |
| 26 | `row 26: ast lint` | the row module has no `if`, comparison, `assert`, or boolean operator on an observation. The lint's own mutant is red, and a loop is not |
| 27 | `row 27: tree unchanged` | the visible tree outside `.git` and `out/` hashes the same. A seed rewrite is red, and so is a write into `tools/` |

Deleted, with the reason:

| old check | why it is gone |
|---|---|
| step-lint | the AST lint replaced it |
| row-proof and `--prove` | one prove loop runs on every verify. A sibling branch is not a proof |
| driver-test and `HEX0_DRIVER_TEST` | the timer flag and the signal rows cover a step that exits and a step that is killed. The forgeable constant is gone |
| `HEX0_SANDBOX`, `HEX0_SCRATCH`, `HEX0_TIME_SCALE`, `HEX0_ROW_PROOF_ONLY` | no environment variable chooses the sandbox or scales a budget |
| the outer `tar \| sha256sum` | it hashed the empty input when `.git` was a gitfile. The new check hashes every file under the resolved git dir |
| fuzz status and letter mutants as a second program | the observation mutants of the fuzz judge run in the same prove loop |
| fd 300 via `ulimit -n 524288` | that raised the hard limit. The row now sets the soft limit to 301 |
| rule 7's spelling scan of shell redirects | the before/after hash of the visible tree is the check |
| two tiers | there is one tier |
