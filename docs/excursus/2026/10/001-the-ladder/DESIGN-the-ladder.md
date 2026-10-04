# DESIGN — the ladder: watc from a seed you can read

2026-10-03. The builder: *"rather than keeping a magic binary... how do we express this in assembly?... that's the real
highest rung?"* and *"wat takes material form this day"*.

## What it is

A full-source bootstrap. The only binary taken on faith is a seed of a few hundred bytes. It is written as commented
hex, so a person can audit it byte against instruction. Each rung is built by the rung below it, from source in this
repository, until watc exists. From there watc compiles itself, as it does today in watmin/the-little-wat.

```
seed/hex0         hand-auditable; turns commented hex into bytes          ← rung 0 (this strike)
  hex1 / hex2     hex plus labels, then relative addresses               ← rung 1
  M0              a macro assembler: mnemonics are DEFINEs that expand to bytes
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

## The rules every rung follows

1. **Each rung is its own source.** A rung's program is written in the language of the rung below it, and is checked
   in beside the binary that rung produces.
2. **Each rung reaches a fixpoint where it can.** hex0 assembling `hex0.hex0` reproduces `seed/hex0` byte for byte.
3. **Every refusal is total and named.** Bad input stops with a distinct, nonzero, documented exit status; it is never
   ignored. That is wat's totality ruling, applied from the first byte.
4. **Every rung is small enough to read in one sitting.** The ladder exists because a person can follow it.
