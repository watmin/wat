# Proposal 018 — Binary-Level Constants and Drain Patterns

**Date:** 2026-04-11
**Author:** watmin + machine
**Status:** PROPOSED
**Source:** Rust↔wat divergence found by the ignorant, fifth pass

## The divergence

The Rust binary (`src/bin/enterprise.rs`) has:
- `BATCH_SIZE = 50` — progress display interval
- `MAX_DRAIN = 5` — learning signal drain cap per candle per consumer
- A learn-signal drain loop in each observer/broker thread

The wat binary (`wat/bin/enterprise.wat`) has none of these. The
drain pattern (try-recv up to N, then continue) is the mechanism
that makes Proposal 012 (exist in the moment) work — it caps the
learning per candle so the hot path stays constant-time.

## The question

How should the wat express:

1. **Named constants** — `MAX_DRAIN = 5` is not a magic number. It's
   the CRDT convergence lever from Proposal 012. It has meaning. How
   does the wat name and declare it?

2. **The drain pattern** — `(while drained < max (try-recv pipe) → apply → inc)`.
   This is the CSP scheduling decision: buffer learning signals,
   process at most N per candle, let the rest converge later. Is this
   a named form (`drain`)? A pattern the reader recognizes? Or inline
   code?

3. **Constructor wiring** — the wat `make-post` takes `dims` and
   `recalib-interval` as parameters. The Rust `Post::new` does not —
   those go into observer/broker constructors individually. Who
   threads the construction-time constants?

## For the designers

1. Should `MAX_DRAIN` be a `(define MAX_DRAIN 5)` at module level?
   Or a field on the process? Or a parameter to `drain`?

2. Is `drain` a language form (like `fold`)? Or a library pattern
   (like `filter-map`)? It recurs in every persistent process.

3. The constructor wiring question: should the wat's post constructor
   match the Rust exactly (no dims/recalib), or is the wat's version
   a valid specification-level simplification (the post DOES depend
   on dims through its observers)?
