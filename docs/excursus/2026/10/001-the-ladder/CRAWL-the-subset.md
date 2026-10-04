# CRAWL — the subset watc is written in (wat0's specification)

2026-10-03. Measured on watmin/the-little-wat `7714f83`, files `elf/compile.wat` plus `elf/lib/{asm,prim,reader,runtime,x86}.wat`.
That is 15,136 lines and 19,404 list forms, counted once by a throwaway tokenizer that tallied every list head.

**Syntax ruling (the builder, 2026-10-04): this repository supports only Clojure/EDN-compliant syntax.** Every name is
a namespaced symbol (`wat.core/defn`, `wat.core/+`), types are ascribed with `:-`, and the colon-path spellings are
not supported here, nor are the `<-`/`->` annotations. watc's source in the-little-wat is still written in the retired
syntax, so moving watc here means translating it first (see "What carries the risk"). The vocabulary below is written
in the compliant spelling.

## Why this is the first step

The full-source bootstrap has one hard rung: **wat0**, an interpreter written in assembly that runs watc's source once
to produce the first native watc. From there, watc rebuilds itself to a fixpoint in seconds, as it does today. wat0 does
not have to run *wat*. It has to run **the subset watc is written in**, because that is what self-hosting means. This
census is that subset, counted rather than recalled.

## What the source uses

Every list head, by kind:

| head kind | uses | what wat0 provides |
|---|---:|---|
| a language operation (`wat.core/…`, `wat.string/…`, …) | 8,893 | the 53 operations below |
| a call to a user function | 8,673 | `wat.core/defn` (1,121 functions); calls, and self tail calls as loops |
| a record field read | 738 | `wat.core/defrecord` (29 records); how a field is read is open question Q1 below |
| an enum variant (`u/Box.Full` in the compliant spelling) | 205 | `wat.core/defenum` (3 enums: the reader's node kind and fault, and the compiler's read kind) |
| `:else` | 153 | `wat.core/cond`'s last clause |
| a record constructor (`(u/some-rec :something 42 :another 32)`) | 99 | keyword-argument construction |

**The 53 operations**:

- **forms:** `wat.core/defn` `wat.core/defrecord` `wat.core/defenum` `wat.core/if` `wat.core/let` `wat.core/cond`
  `wat.core/do` `wat.core/and` `wat.core/or` `wat.core/not` `wat.core/match`, plus a type alias and a file load
- **i64:** `wat.core/+` `-` `*` `/` `quot` `rem` `=` `not=` `<` `<=` `>` `>=`; `wat.i64/bit-and` `bit-or`
  `bit-shift-left` `bit-shift-right` `to-string`
- **String:** `wat.string/concat` `length` `byte-length` `subs` `byte-subs` `byte-at` `starts-with?`
- **Vector:** construction, `wat.core/nth` `length` `conj` `assoc`
- **Bytes and I/O:** hex ↔ bytes, read a whole file, open/write-all/flush/close a file for writing,
  `wat.kernel/println`
- **failure:** `wat.kernel/assertion-failed!` and a test equality assertion

**Open questions for the builder** (asked 2026-10-04, `LAYOUT.md` rule 8: asked, never guessed). They are settled
before wat0's brief is drawn, which is where they are first needed:
- **Q1.** How code reads a record field.
- **Q2.** Whether records and enum variants construct with one shape. Today records take keyword arguments and variants
  take a map.
- **Q3.** Whether `u/` and `user/` are one namespace, and how a namespace is declared.
- **Q4.** The compliant spellings of the I/O and Bytes operations, the type alias, the file load and the test assertion.
- **Q5.** Whether wat-rs main's arc-251 surface is the grammar watmin/wat follows.

**Types:** `wat.type/i64`, `wat.type/String`, `wat.type/bool`, `nil`, the Vector type, records, the three enums, and
`Option` (one `Some`, one `None`).

**What it does not use:** `fn` (closures), maps and sets, macros, services, threads, the holon algebra, `try`, and
floats. The interpreter wat0 has to be is a small, strict Scheme with records and tagged unions. It is not wat.

## What carries the risk

1. **Byte-identical output.** wat0's stage-1 watc must be byte-identical to the one wat-rs's stage 0 builds. That is
   Wheeler's diverse double-compiling, and it is wat0's acceptance gate. Every operation has to match wat-rs's
   semantics exactly where watc's source exercises it. For example: `length` versus `byte-length` on the strings the
   source contains, `quot`/`rem`/`/` on negatives, and the i64-to-string conversion.
2. **Memory.** wat0 runs once, so an arena that never frees is the simplest heap. But an interpreter allocates far
   more than compiled code does: watc compiling itself natively peaked at ~446 MB before freeing existed. Measure
   before choosing between an arena and counts. wat-rs's stage-0 peak RSS is a first, rough reference. This crawl
   does not decide it: wat0's brief carries the measurement as a row.
3. **Recursion depth.** watc's source is written for a compiler that turns SELF tail calls into loops (F-211: mutual
   ones are not). So wat0 needs self tail calls as loops, and a native stack deep enough for its non-tail recursion.
4. **Time.** Today's stage 0 interprets watc compiling 103 programs (~31–48 min on wat-rs). The bootstrap needs only
   one of them: watc compiling itself.
5. **The syntax translation.** watc's ~15,000 lines must be translated to the compliant syntax before wat0 can run
   them, and watc's reader must accept only that syntax. The translation is mechanical. A tool reads the old form and
   prints the new one, and wat-rs (which still reads the old form) checks that both spellings mean the same program.
   It is a named step on the ladder (`DESIGN-the-ladder.md`), before wat0.

## The ladder below wat0

It is drawn in `DESIGN-the-ladder.md`: the seed, hex1, hex2, M0, the syntax translation, wat0, then watc.
