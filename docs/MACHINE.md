# The machine — what a fresh box needs

wat builds from its own seed. Nothing below is used to BUILD any rung of the ladder, except the one seed decode named in `docs/LAYOUT.md` rule 4 (`docs/excursus/2026/10/001-the-ladder/DESIGN-the-ladder.md`).
These tools CHECK and MEASURE: they decode hex independently, disassemble, trace syscalls, and compare against C.

Verified on the builder's machine, 2026-10-03: Omarchy (Arch), x86-64, kernel 7.2.

## Omarchy / Arch

```
sudo pacman -S --needed tinyxxd strace ltrace valgrind hexyl gdb binutils perf nasm yasm python git github-cli gcc make
```

## Debian / Ubuntu

```
sudo apt install xxd strace ltrace valgrind hexyl gdb binutils linux-perf nasm yasm python3 git gh gcc make
```

On Ubuntu, `linux-perf` is `linux-tools-common linux-tools-$(uname -r)`. On older Debian, `xxd` ships inside
`vim-common`.

## What each is for

| tool | Arch package | Debian package | used to |
|---|---|---|---|
| `xxd` | `tinyxxd` | `xxd` | decode a rung's hex independently; read binaries |
| `hexyl` | `hexyl` | `hexyl` | read seed bytes beside their comments |
| `objdump`, `readelf` | `binutils` | `binutils` | disassemble a rung; check ELF headers |
| `nasm`, `yasm` | `nasm`, `yasm` | `nasm`, `yasm` | cross-check hand-encoded instructions (never to build) |
| `strace` | `strace` | `strace` | confirm a rung makes only the syscalls it claims |
| `gdb` | `gdb` | `gdb` | step a rung; hardware watchpoints |
| `perf` | `perf` | `linux-perf` | instruction and cycle counts (reported separately) |
| `valgrind`, `ltrace` | `valgrind`, `ltrace` | `valgrind`, `ltrace` | memory and cache profiles; library calls in C comparisons |
| `gcc`, `make` | `gcc`, `make` | `gcc`, `make` | the sandbox fault injector and the argc helpers. Not a builder of a rung |
| `python3` | `python` | `python3` | the check scripts under `tools/check/` |
| `git`, `gh` | `git`, `github-cli` | `git`, `gh` | the repositories; GitHub is the disaster-recovery site |

`/tmp` is a tmpfs on this machine and a reboot wipes it. Long-lived sandboxes go under `/var/tmp`.

## What the decodes are

`sed` stripping comments, then `xxd -r -p` packing the hex, is an independent decode. It shares no code with the gate's Python. `tools/check/hex-check.py` is a second reader, and both its decode and its digit listing consume one tokenizer. The fixpoint, the seed reading its own source, proves self-consistency, not trust.

## What the gate runs

The gate is `tools/verify`. It needs Python ≥ 3.11 and git ≥ 2.32. It runs `sed`, `xxd`, `objdump`, `strace`, `gcc` and `unshare`. `gcc` builds the fault injector and the argc helper in the sandbox. It does not build a rung. `sed` then `xxd`, and `tools/check/hex-check.py`, agree on the seed byte for byte. The trust is the hand audit, not which reader ran first.

`nasm`, `yasm`, `gdb`, `perf`, `valgrind`, `ltrace`, `hexyl` and `make` are measurement tools. None of them is on the gate's path. A measurement is bound to the rung that names it. This rung names none of them. `gh` is the disaster-recovery client, not a gate tool.

## What the gate needs

- A user without `CAP_DAC_OVERRIDE` effective. The plain read-only row refuses to run while that capability is effective, and names the capability. The capability row reproduces the other result under `unshare -U`.
- A soft `NOFILE` limit of about 301. The gate does not raise the hard limit.
- A git working tree, not merely a checkout of files. Rule 6 compares `archived/` with commit `c45603e`, which a source archive does not contain.
- Exec permission on `/var/tmp`. The sandbox is one directory the gate creates there. No environment variable chooses it.
- `kernel.yama.ptrace_scope` of 0 or 1, so the fault injector can trace the Nth matching syscall of a child it spawned.
