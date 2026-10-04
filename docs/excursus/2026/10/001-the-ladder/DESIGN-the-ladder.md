# DESIGN — the ladder: watc from a seed you can read

2026-10-03. The builder: *"rather than keeping a magic binary... how do we express this in assembly?... that's the real
highest rung?"* and *"wat takes material form this day"*.

## What it is

A full-source bootstrap. One per target: that target's seed, a few hundred bytes. It is written as commented
hex, so a person can audit it byte against instruction. Each rung is built by the rung below it, from source in this
repository, until watc exists. From there watc compiles itself, as it does today in watmin/the-little-wat.

```
ladder/0-hex0     the seed: hand-auditable; turns commented hex into bytes ← rung 0 (x86_64-linux first)
  hex1            hex plus labels                                        ← rung 1
  hex2            hex plus labels and relative addresses                 ← rung 2
  M0              a macro assembler: mnemonics are DEFINEs that expand to bytes
  (translation)   watc's source restated in the Clojure/EDN-compliant syntax, checked by wat-rs reading both
  wat0            an interpreter for the subset watc is written in        ← CRAWL-the-subset.md
  watc            wat0 runs watc's source once → stage 1; stage 1 == stage 2
```

The rung shapes are the ones bootstrappable-builds (stage0-posix, live-bootstrap) proved. The code is our own.

The gate checks artifacts. It does not build a rung and it does not sequence the ladder. Running the seed on a fixture is an observation. For hex1, the top-level `build` produces hex1 and the gate checks it. Bash issues that build until M0's brief.

## What is given, and what is not

- **Given:** each target's architecture, and the Linux kernel on that architecture. Programs talk to it only through
  syscalls. wat is a Linux language, so the kernel is the platform, not a dependency.
- **The sequencer, until M0's brief, is bash.** The top-level `build` runs
  `ladder/0-hex0/x86_64-linux/hex0` on `ladder/1-hex1/x86_64-linux/hex1.hex0`, writing `out/hex1`, then runs
  `out/hex1` on `ladder/1-hex1/x86_64-linux/hex1.hex1`, writing `out/hex1-self`. The gate checks those products.
  It does not call `build`.
- **Not given:**
  - no libc;
  - no dynamic loader;
  - no assembler or compiler from elsewhere;
  - no binary except that target's seed.

  Every artifact above the seed is built by the rung below it.
- **Checking is not building.** Shell, `xxd` and Python may CHECK a rung. `sed` and `xxd` decode the seed
  independently. `hex-check.py` is a second reader of the same source. The two agree byte for byte. The trust is the hand audit, not which reader ran first. The fixpoint proves self-consistency, not trust.
  No rung's OUTPUT may come from them. The gate does not sequence the ladder.

## Targets

A rung is one contract with per-target implementations. The input language, the exit statuses and the fixtures belong
to the rung. The machine code and syscalls belong to a target, `<arch>-<os>` (`x86_64-linux` first). Another
architecture or OS later is a new target directory under each rung, held to the same README and the same tests, with
its own hand-auditable seed. A host runs the contract rows for every target it can execute, and checks every target's
bytes (decode and byte identity), which needs no execution.

Syscall numbers are per target. The table is `ladder/<n>-<name>/<arch>-<os>/syscalls.tsv`: one row for each call
that target makes, the number and the name. That file exists for the x86-64 Linux seed, and the fault rows and the
syscall allow-list read it.

Per-target facts the gate reads live in `gate.tsv` in that same directory. The column order is the key, then a tab, then the value. One row is a key, a tab, and a value. The x86-64 Linux file holds the seed size, the objdump machine, the instruction width, the code base, the row-9 mutant text, the fuzz patterns, and the two truncate-order byte sequences. `trunc_fchmod_then_ftruncate` is fchmod then ftruncate. `trunc_ftruncate_then_fchmod` is the reverse: a faulted fchmod then leaves the file truncated.

## Which targets, and nothing more

The builder, 2026-10-04: *"i want to discard as much legacy stuff as possible here.. i have zero intentions on
targetting all possible things.... for now this laptop (probably an rpi i have laying around later for early arm
support....) we'll move on to other cpu archs (riscv if i can get my hands on one) and cpu extensions"*.

Targets are machines in hand, in order. There is no portability for its own sake.

| target | the machine | ISA baseline it may assume | in hand |
|---|---|---|---|
| `x86_64-linux` | this laptop: Intel i7-1270P, Linux 7.2, 4 KiB pages | **x86-64-v3**: AVX2, BMI2, FMA, MOVBE (measured from `/proc/cpuinfo` and the loader, 2026-10-04). **No AVX-512.** | yes |
| `aarch64-linux` | not a target until a machine is in hand | measured on that machine | no |
| `riscv64-linux` | not a target until a machine is in hand | measured on that machine | no |

A CPU extension enters a target only when a machine in hand has it. Code may use anything its target's baseline
guarantees; nothing below it is kept for an older CPU nobody here runs.

## Calling convention: wat's own, not SysV

The builder, 2026-10-04: *"we are not targetting any FFI with anything"*, and *"i want us to be unburdened by classical
techniques.. this is modern and needs to behave like a modern solution"*.

**wat calls only wat.** There is no foreign function interface, so no C ABI is owed: no System V AMD64 calling
convention, no AAPCS. The only outside contracts are the kernel's, at the boundary, where they are not a choice:
- **the Linux syscall ABI:** on x86-64, the number in `rax`, arguments in `rdi rsi rdx r10 r8 r9`, the result in
  `rax`, and `rcx`/`r11` clobbered;
- **the process entry state `execve` builds:** argc at `[rsp]`, then argv and envp;
- **the ELF file format.**

Everything inside is wat's. One convention per target, written down once, follows. The x86-64 row is the partition described for watc (the-little-wat, `elf/lib/x86.wat`). The hex0 gate does not check that partition. The aarch64 column stays out of this table until a machine is in hand.

| role | `x86_64-linux` |
|---|---|
| arguments | `rdi rsi rdx rcx r8 r9 r10 r11` (eight) |
| return | `rax` |
| preserved across a call | `rbx r12 r13` |
| frame pointer, always | `rbp` |
| reserved, never allocated | `rsp`; `r14` runtime header; `r15` heap top |

**Discarded, deliberately:**
- **A red zone.**
- **varargs.**
- **Callee-saved registers chosen for C's sake.**
- **Any libc or errno global.**

**Decided 2026-10-04.** The builder: *"we must be exemplars in linux systems programming - we adhere to what linux
requires"*, *"we need you and grok to debug effortlessly"*, and *"we are the best and we prove it relentlessly"*.

- **The syscall boundary follows Linux exactly.**
  - A `syscall` (x86-64) or `svc #0` (aarch64) instruction appears only in one per-target set of syscall routines,
    never in general code.
  - Each routine moves wat's arguments into the kernel's registers: `rdi rsi rdx r10 r8 r9` with the number in `rax`
    on x86-64, and `x0`–`x5` with the number in `x8` on aarch64.
  - Each routine declares `rcx` and `r11` clobbered on x86-64, because the kernel clobbers them.
  - The result is the kernel's: a value, or `-errno` in −4095..−1, tested where it is used.

  The collision with wat's argument registers lives in that one audited place.
- **Frame pointers are always on, with no flag.**
  - A flag is two shapes of every routine and two things to test; the binary you run is the binary you debug.
  - It is the modern choice: Fedora, Ubuntu 24.04 and Arch re-enabled frame pointers distro-wide for `perf`, eBPF and
    gdb stack walks, at a measured cost of about 1%.
  - `rbp` (and `x29`) is the frame pointer, so it is not in the preserved pool.
  - Debugging by name needs names too: every rung above the seed emits an ELF symbol table, so gdb and `perf` show
    routines, not addresses. The seed stays a program audited by offset.
- **The stack pointer is 16-byte aligned at every call, on every target, starting with the first rung that contains a `call`.** The seed has no `call`. This reverses what this section first
  listed under "discarded", for these reasons:
  - aarch64 hardware faults on a memory access through an unaligned `sp`;
  - x86-64 does not require alignment, but aligned AVX2 spills want it, and values straddling a cache line cost time;
  - one invariant across targets is simpler than two, and on x86-64 it costs a few bytes of padding per frame.

  The first rung that contains a `call` carries an alignment row in its EXPECTATIONS. hex0 has no `call`, so this gate does not check alignment. A routine that
  needs 32-byte alignment for AVX2 aligns locally, for a measured reason.

The seed (rung 0) has no routines at all: 0 `call`, `ret`, `enter` or `leave` instructions. It meets only the kernel's
contracts. Its `push imm; pop reg` is a 3-byte constant load, not a frame.

## The rules every rung follows

1. **Each rung is its own source.** A rung's program is written in the language of the rung below it and checked in
   under `ladder/<n>-<name>/`. Its binary is built into `out/`, never committed. One committed binary per target: the
   seed (`docs/LAYOUT.md`).
2. **Each rung reaches a fixpoint where it can.** hex0 assembling `hex0.hex0` reproduces `ladder/0-hex0/x86_64-linux/hex0` byte for byte.
3. **Every refusal is total and named.** Bad input stops with a distinct, nonzero, documented exit status; it is never
   ignored. That is wat's totality ruling, applied from the first byte. Its stated bounds are what the kernel decides,
   not the program: a signal ends a process without a status, and a read from a FIFO or terminal can block. Each
   rung's README states them.
4. **Every rung is small enough to read in one sitting.** The ladder exists because a person can follow it.
