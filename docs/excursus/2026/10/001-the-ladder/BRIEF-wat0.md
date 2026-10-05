# BRIEF — wat0, the interpreter

2026-10-04. The builder asked for this document after M0 could carry a program. This is the brief for wat0. It is not M0's brief, and bash remains the sequencer until that one exists. The interpreter is not started by this file.

The census is `CRAWL-the-subset.md`. The ladder is `DESIGN-the-ladder.md`. Q1 through Q5 are ruled there. Five dilemmas at the end of that crawl are still asked, and they are repeated below. The reader is not guessed.

## The program

wat0 is a static x86-64 Linux ELF. It is written as M0 source: hex2 text plus `(define name ...)` lists. Hex2 emits the binary. The program uses syscalls only. It does not link libc.

It interprets the subset the compiler is written in, once, and that run produces the first native compiler. From there the compiler rebuilds itself. wat0 does not have to run wat. The directory, when the program is written, is `ladder/4-wat0/`. Rule 4 requires the lowercase name. The contract will be that rung's README. This brief does not create the directory.

## What it runs

The census, measured on watmin/the-little-wat `7714f83`, is the language:

- lists, and the forms `wat.core/defn`, `wat.core/defrecord`, `wat.core/defenum`, `wat.core/if`, `wat.core/let`, `wat.core/cond`, `wat.core/do`, `wat.core/and`, `wat.core/or`, `wat.core/not`, `wat.core/match`
- the 53 operations named in the census, including the integer, string, vector, bytes, and file operations the compiler's own source uses
- 29 records and 3 enums
- names by the first-slash rule, with binders in `$bound`

The census excludes closures, macros, maps, sets, services, threads, `try`, and floats.

A self tail call is a loop. A mutual tail call stays a call. The native stack has to hold the non-tail recursion of the one compilation. If it does not, that is a measured depth, named in SCORE, and the stack is raised to fit. No depth is guessed here.

## How it is built

Bash, the top-level `build`, remains the sequencer. When the source exists it runs M0 on wat0's M0 source, then hex2 on that hex2 text. The gate checks the product. It does not call `build`.

wat0's own source is one file in `x86_64-linux/`, the same shape as M0. A reason to split it is a stop, not a guess.

## Acceptance

wat0 runs the translated compiler once. The native compiler that run produces is byte-identical to the compiler wat-rs's stage 0 produces from the same source. That comparison is the gate for this rung. The operations match wat-rs where the compiler's source exercises them, including `length` and `byte-length`, `quot`, `rem`, and `/` on negatives, and the conversion of an i64 to a string.

The bootstrap needs that one compilation. It does not need the interpreter to compile the other programs wat-rs's stage 0 compiles.

## The heap row

wat0 runs once, so an arena that never frees is the simple heap, and counts are the other candidate. The census does not choose. This brief does not choose either. Before the interpreter is written, SCORE records one measurement: the peak resident memory of wat-rs's stage 0 compiling the compiler. The heap is chosen from that number. The native compiler's own peak, about 446 MB before freeing existed, is the scale the census already names. It is not a substitute for the measurement.

## The translation

The compiler's source in the-little-wat is still the retired spelling. wat0 runs only the compliant spelling. The translation is the ladder step before this rung runs the compiler. A tool reads the old form and prints the new one. wat-rs reads both and checks that they are the same program. That tool is not this brief, and it is not wat0.

## Ruled 2026-10-04

The builder ruled the value spellings. Uppercase names are a convention. Nothing requires them.

An enum requires a purity marker. Variants are names, and a variant is built from a map. `wat.core/Option` is the core spelling:

```clojure
(wat.core/defenum wat.core/Option :- [T] wat.enum/Pure
  Some [value :- T]
  None [])

(wat.core/let
  [some (wat.core/Option.Some {:value 42})
   none (wat.core/Option.None {})]
  (wat.core/match some
    [wat.core/Option.Some {:value value} (wat.kernel/println value)]
    [wat.core/Option.None {}             (wat.kernel/println nil)]))
```

A name in another namespace uses the same shape. `(wat.core/defenum u/box :- [T] wat.enum/Pure full [x :- T] empty [])` builds `(u/box.full {:x 42})`.

A record is built from a map. One field is the record name, a slash, and the field. Several fields can be bound at once with `:keys` in a `wat.core/let` binding:

```clojure
(wat.core/defrecord u/SomeRec
  [some-field :- wat.type/i64
   another-field :- wat.type/keyword])

(wat.core/let
  [r (u/SomeRec {:some-field 42 :another-field :some-value})
   {:keys [some-field another-field]} r]
  (wat.core/do
    (wat.kernel/println some-field)
    (wat.kernel/println (u/SomeRec/some-field r))))
```

The bytes namespace is `wat.bytes/`.

## Proposed, not ruled

These are the operation names the compiler's own source already matches, in the compliant spelling. The builder will confirm or correct them.

| operation | proposed spelling |
|---|---|
| byte length of a string | `wat.string/byte-length` |
| byte slice of a string | `wat.string/byte-subs` |
| byte at an index | `wat.string/byte-at` |
| bitwise and, or | `wat.i64/bit-and`, `wat.i64/bit-or` |
| shift left, arithmetic shift right | `wat.i64/bit-shift-left`, `wat.i64/bit-shift-right` |
| logical shift right | `wat.i64/unsigned-bit-shift-right` |
| replace a vector index | `wat.core/assoc` |
| hex of bytes, bytes of hex | `wat.bytes/to-hex`, `wat.bytes/from-hex` |
| read a whole file as bytes | `wat.io/read-bytes` |

`wat.io/read-file` stays the read that returns a string. The compiler's primitive today opens a file and then reads all of it. `wat.io/read-bytes` is the one-shot proposed beside that. `wat.i64/unsigned-bit-shift-right` is in the compiler and was not in the census list.

A quoted string and a decimal immediate stay asked on M0. wat0 does not need either to be specified.

## Stop

- An operation spelling above is used and the builder has not confirmed it.
- The heap measurement is not in SCORE. Do not pick an arena or counts.
- The translated compiler and the wat-rs reading of both spellings do not agree. Do not point wat0 at the retired source.
- wat0's source would need a language M0 does not have. Say what, and why. M0 stays the macro step. wat0 stays the interpreter.
