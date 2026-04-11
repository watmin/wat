# Proposal 017 — Explicit ScalarEncoder Threading

**Date:** 2026-04-11
**Author:** watmin + machine
**Status:** PROPOSED
**Source:** Rust↔wat divergence found by the ignorant, fifth pass

## The divergence

The Rust `ScalarAccumulator::observe()` and `ScalarAccumulator::extract()`
take `&ScalarEncoder` as an explicit parameter. The wat `observe-scalar`
and `extract-scalar` call encoding primitives directly — `encode-log`,
`encode-linear`, `encode-circular` — without threading an encoder through.

The Rust threads it. The wat assumes it's ambient.

## The question

Should the wat thread the ScalarEncoder explicitly (matching the Rust)?
Or is the ambient access a valid language-level simplification — the
encoder IS ambient because it depends only on dims, which is a
construction-time constant?

The Rust threads it because Rust has no ambient state — everything
is explicit. The wat could choose differently — if the encoder is
deterministic and depends only on dims, making it ambient simplifies
every call site at no cost to correctness.

## For the designers

1. Is ambient ScalarEncoder honest? It depends only on dims. It has
   no mutable state. It's deterministic. Is hiding it dishonest or
   is threading it ceremony?

2. If ambient: how? A module-level binding? A ctx field that every
   function can reach? An implicit parameter?

3. If explicit: the wat must add `scalar-encoder` as a parameter to
   `observe-scalar`, `extract-scalar`, and every call site that uses
   them. This matches the Rust exactly.
