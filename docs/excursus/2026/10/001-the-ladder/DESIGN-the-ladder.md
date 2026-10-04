# DESIGN — the ladder: watc from a seed you can read

2026-10-03. The builder: *"rather than keeping a magic binary... how do we express this in assembly?... that's the real
highest rung?"* and *"wat takes material form this day"*.

## What it is

A full-source bootstrap. The one binary not built from source is a seed of a few hundred bytes. It is written as commented
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

## What is given, and what is not

- **Given:** the Linux kernel on x86-64. Programs talk to it only through syscalls. wat is a Linux language, so the
  kernel is the platform, not a dependency.
- **Not given:**
  - no libc;
  - no dynamic loader;
  - no assembler or compiler from elsewhere;
  - no binary except the seed.

  Every artifact above the seed is built by the rung below it.
- **Checking is not building.** Shell, `xxd` and Python may CHECK a rung, for example by decoding the seed's hex
  independently and comparing bytes. No rung's OUTPUT may come from them.

## Targets

A rung is one contract with per-target implementations. The input language, the exit statuses and the fixtures belong
to the rung. The machine code and syscalls belong to a target, `<arch>-<os>` (`x86_64-linux` first). Another
architecture or OS later is a new target directory under each rung, held to the same README and the same tests, with
its own hand-auditable seed. A host runs the contract rows for every target it can execute, and checks every target's
bytes (decode and byte identity), which needs no execution.

Syscall numbers are per target. The table is `ladder/<n>-<name>/<arch>-<os>/syscalls.tsv`: one row for each call
that target makes, the number and the name. The fault rows and the syscall allow-list read it. The brief that adds
the second executable target is the one that cuts the gate over to that table. With one target, the x86-64 Linux
numbers stay in the hex0 contract check.

## Which targets, and nothing more

The builder, 2026-10-04: *"i want to discard as much legacy stuff as possible here.. i have zero intentions on
targetting all possible things.... for now this laptop (probably an rpi i have laying around later for early arm
support....) we'll move on to other cpu archs (riscv if i can get my hands on one) and cpu extensions"*.

Targets are machines in hand, in order. There is no portability for its own sake.

| target | the machine | ISA baseline it may assume |
|---|---|---|
| `x86_64-linux` | this laptop: Intel i7-1270P, Linux 7.2, 4 KiB pages | **x86-64-v3**: AVX2, BMI2, FMA, MOVBE (measured from `/proc/cpuinfo` and the loader, 2026-10-04). **No AVX-512.** |
| `aarch64-linux` | a Raspberry Pi, later | to measure on the board when it arrives |
| `riscv64-linux` | if one is acquired | to measure then |

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

Everything inside is wat's. One convention per target, written down once, follows. The x86-64 row is the partition
watc already designed (the-little-wat, `elf/lib/x86.wat`, the comment above `:c::nargregs`):

| role | `x86_64-linux` | `aarch64-linux` |
|---|---|---|
| arguments | `rdi rsi rdx rcx r8 r9 r10 r11` (eight) | `x0`–`x7` (eight) |
| return | `rax` | `x0` |
| preserved across a call | `rbx r12 r13 rbp` | chosen with the target |
| reserved, never allocated | `rsp`; `r14` runtime header; `r15` heap top | chosen with the target |

**Discarded, deliberately:**
- **16-byte stack alignment at every call.** That is SysV's, inherited from SSE. The stack is aligned only where an
  instruction needs it.
- **Mandatory frame pointers and prologue rituals.** A routine keeps what it uses.
- **A red zone.**
- **varargs.**
- **Callee-saved registers chosen for C's sake.**

**Each is decided once, here, before the first rung with routines (wat0, and M0 if it has any):**
- **Q6.** The syscall shim on x86-64. The kernel takes its fourth argument in `r10` and clobbers `rcx` and `r11`, which
  are wat argument registers. Where is the one place the shim moves them?
- **Q7.** Frame pointers. Keep them for gdb backtraces in the ladder's rungs, or drop them everywhere?
- **Q8.** Stack alignment. Where it is actually needed: AVX2 loads, if wat0 uses them.

The seed (rung 0) has no routines at all: 0 `call`, `ret`, `enter` or `leave` instructions. It meets only the kernel's
contracts. Its `push imm; pop reg` is a 3-byte constant load, not a frame.

## The rules every rung follows

1. **Each rung is its own source.** A rung's program is written in the language of the rung below it and checked in
   under `ladder/<n>-<name>/`. Its binary is built into `out/`, never committed. The seed is the one committed binary
   (`docs/LAYOUT.md`).
2. **Each rung reaches a fixpoint where it can.** hex0 assembling `hex0.hex0` reproduces `ladder/0-hex0/x86_64-linux/hex0` byte for byte.
3. **Every refusal is total and named.** Bad input stops with a distinct, nonzero, documented exit status; it is never
   ignored. That is wat's totality ruling, applied from the first byte. Its stated bounds are what the kernel decides,
   not the program: a signal ends a process without a status, and a read from a FIFO or terminal can block. Each
   rung's README states them.
4. **Every rung is small enough to read in one sitting.** The ladder exists because a person can follow it.
