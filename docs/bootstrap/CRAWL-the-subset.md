# CRAWL — the subset watc is written in (wat0's specification)

2026-10-03. Measured on watmin/the-little-wat `7714f83`, files `elf/compile.wat` plus `elf/lib/{asm,prim,reader,runtime,x86}.wat`.
That is 15,136 lines and 19,404 list forms. Reproduce with:

```
python3 docs/bootstrap/vocab.py elf/compile.wat elf/lib/*.wat
```

## Why this is the first step

The full-source bootstrap has one hard rung: **wat0**, an interpreter written in assembly that runs watc's source once
to produce the first native watc. From there, watc rebuilds itself to a fixpoint in seconds, as it does today. wat0 does
not have to run *wat*. It has to run **the subset watc is written in**, because that is what self-hosting means. This
census is that subset, counted rather than recalled.

## What the source uses

Every list head, by kind:

| head kind | uses | what wat0 provides |
|---|---:|---|
| a `:wat::…` language operation | 8,893 | the 53 operations below |
| a call to a user function | 8,673 | `defn` (1,121 functions); calls, and self tail calls as loops |
| a record accessor (`:c::Out/code`) | 738 | `defrecord` (29 records): positional fields |
| an enum variant (`:rd::Kind.List`) | 205 | `defenum` (3 enums: `:rd::Kind`, `:rd::Fault`, `:c::Read`) |
| `:else` | 153 | `cond`'s last clause |
| a record constructor (`(:c::Out :base b …)`) | 99 | keyword-argument construction |

**The 53 operations**, with both spellings (`:wat::core::+` and `wat.core/+`) merged:

- **forms:** `defn` `defrecord` `defenum` `typealias` `if` `let` `cond` `do` `and` `or` `not` `match`
  `load-file!`
- **i64:** `+` `-` `*` `/` `quot` `rem` `=` `not=` `<` `<=` `>` `>=` `bit-and` `bit-or` `bit-shift-left`
  `bit-shift-right` `i64::to-string`
- **String:** `concat` `length` `byte-length` `subs` `byte-subs` `byte-at` `starts-with?`
- **Vector:** `Vector` (construction) `nth` `length` `conj` `assoc`
- **Bytes and I/O:** `Bytes::from-hex` `Bytes::to-hex` `io::read-file` `IOReader/open-file` `IOReader/read-all`
  `IOWriter/open-file` `IOWriter/write-all` `IOWriter/flush` `IOWriter/close` `kernel::println`
- **failure:** `kernel::assertion-failed!` `test::assert-eq`

**Types:** `i64`, `String`, `bool`, `nil`, `Vector`, records, the three enums, and `Option` (one `Some`, one
`None`).

**What it does not use:** `fn` (closures), maps and sets, macros, services, threads, the holon algebra, `try`, and
floats. The interpreter wat0 has to be is a small, strict Scheme with records and tagged unions. It is not wat.

## What carries the risk

1. **Byte-identical output.** wat0's stage-1 watc must be byte-identical to the one wat-rs's stage 0 builds. That is
   Wheeler's diverse double-compiling, and it is wat0's acceptance gate. Every operation has to match wat-rs's
   semantics exactly where watc's source exercises it. For example: `length` versus `byte-length` on the strings the
   source contains, `quot`/`rem`/`/` on negatives, and `i64::to-string`.
2. **Memory.** wat0 runs once, so an arena that never frees is the simplest heap. But an interpreter allocates far
   more than compiled code does: watc compiling itself natively peaked at ~446 MB before freeing existed. Measure
   before choosing between an arena and counts. wat-rs's stage-0 peak RSS is a first, rough reference.
3. **Recursion depth.** watc's source is written for a compiler that turns SELF tail calls into loops (F-211: mutual
   ones are not). So wat0 needs self tail calls as loops, and a native stack deep enough for its non-tail recursion.
4. **Time.** Today's stage 0 interprets watc compiling 103 programs (~31–48 min on wat-rs). The bootstrap needs only
   one of them: watc compiling itself.

## The ladder below wat0 — to be drawn next

The shape bootstrappable-builds proved, with our own code:
- **hex0:** a seed of a few hundred bytes that turns commented hex into a binary. It is hand-auditable.
- **a macro assembler in the M0 style:** mnemonics are DEFINEs that expand to bytes, plus labels. It needs no real
  instruction encoder; watc's own `elf/lib/x86.wat` already holds the encodings it needs.
- **wat0**, written in that assembly, to this crawl's specification.

Then: wat0 runs watc's source to produce stage 1, stage 1 compiles itself to stage 2, and stage 1 == stage 2, the
fixpoint already checked today.
