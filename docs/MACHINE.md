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
| `gcc`, `make` | `gcc`, `make` | `gcc`, `make` | the C programs watc's output is measured against |
| `python3` | `python` | `python3` | the check scripts under `tools/check/` |
| `git`, `gh` | `git`, `github-cli` | `git`, `gh` | the repositories; GitHub is the disaster-recovery site |

`/tmp` is a tmpfs on this machine and a reboot wipes it. Long-lived sandboxes go under `/var/tmp`.

## What the decodes are

`sed` stripping comments, then `xxd -r -p` packing the hex, is an independent decode. It shares no code with the gate's Python. `tools/check/hex-check.py` is a second reader, and both its decode and its digit listing consume one tokenizer. The fixpoint, the seed reading its own source, proves self-consistency, not trust.

## What the gate needs

- A full clone. Rule 6 of `docs/LAYOUT.md` compares `archived/` with commit `c45603e`, which a source archive does not contain.
- A git worktree. The layout rules read `git ls-files` and `git diff`.
- Exec permission on `/var/tmp`. The sandbox and the fault injector are created there.
- `kernel.yama.ptrace_scope` of 0 or 1, so the fault injector can trace the Nth matching syscall of a child it spawned.
