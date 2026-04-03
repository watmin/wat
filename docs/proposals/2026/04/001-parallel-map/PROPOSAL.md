# Proposal 001 — Parallel Map

**Scope:** structural  
**Date:** 2026-04-03

## Current State

Wat has sequential iteration forms inherited from the host language:

```scheme
(map f xs)          → list    ; apply f to each element, collect results
(for-each f xs)     → ()      ; apply f to each element, discard results
(fold f init xs)    → value   ; accumulate left-to-right
```

These are sufficient for correctness. The enterprise fold is sequential and deterministic. Every `map` and `for-each` in the current wat specs evaluates elements one at a time, left to right.

## The Problem

The enterprise's hot path contains independent computations expressed as `map` and `for-each` that the sequential forms cannot communicate as parallelizable:

**Observer encoding** — the dominant cost (~80% of per-candle compute):
```scheme
(map (lambda (obs)
       (encode-thought (:thought-encoder desk) (take-last w window) (:vm ctx) (:lens obs)))
     (:observers desk))
```
Six observers, each encoding from a different window slice. Zero shared state. Zero data dependencies between elements. Pure functions returning independent results. Sequential `map` processes them one at a time.

**Observer prediction** — six independent cosine projections:
```scheme
(map (lambda (obs vec) (predict (:journal obs) vec))
     (:observers desk) observer-vecs)
```

**Observer learning** — six independent journal observations:
```scheme
(for-each (lambda (obs vec) (observe (:journal obs) vec label sw))
          (:observers desk) observer-vecs)
```

**Observer decay** — six independent decay operations:
```scheme
(for-each (lambda (obs) (decay (:journal obs) (:decay config)))
          (:observers desk))
```

**Observer resolution** — six independent resolution updates:
```scheme
(for-each (lambda (obs pred) (resolve obs ...))
          (:observers desk) observer-preds)
```

**Risk branch evaluation** — five independent subspace residual computations.

**Desk-level parallelism** — each desk processes the same raw candle independently through its own indicator bank, candle window, and observer panel. The observe phase is entirely independent across desks.

**Manager context extraction** — multiple independent field projections:
```scheme
(map :curve-valid specialists)
(map (lambda (o) (len (:resolved o))) specialists)
(map :cached-acc specialists)
```

## Proposed Change

Add two parallel forms to the structural layer:

```scheme
;; Parallel map — semantically identical to map.
;; The runtime MAY evaluate elements concurrently.
;; The function must be pure — no set!, push!, inc!, or shared mutable state.
(pmap f xs)                      → list

;; Parallel for-each — semantically identical to for-each.
;; The runtime MAY evaluate elements concurrently.
;; Each element's side effects must be independent — mutations touch
;; disjoint state (e.g., different journal instances, different positions).
(pfor-each f xs)                 → ()
```

**Semantics:** `pmap` and `pfor-each` produce identical results to `map` and `for-each`. The parallelism is a permission, not a requirement. A single-threaded runtime evaluates them sequentially. A multi-core runtime may use thread pools, rayon, or OS threads.

**Safety contract:**
- `pmap`: the mapped function must be pure. No mutation of any kind. The compiler (or ward) rejects `pmap` over lambdas containing `set!`, `push!`, `inc!`, or any form that mutates shared state.
- `pfor-each`: each element's mutations must be independent. The function may mutate state, but each invocation must touch disjoint state. Example: `(pfor-each (lambda (obs) (decay (:journal obs) rate)) observers)` is safe because each observer owns its own journal. The compiler verifies disjointness through ownership — each element's mutations go through a different root object.

**No `pfold`:** A fold is inherently sequential — each step depends on the previous step's output. There is no parallel fold. Reduction of independent results uses `(fold + 0 (pmap f xs))` — the pmap parallelizes, the fold reduces.

## The Algebraic Question

`pmap` does not change the algebra. It does not introduce a new algebraic structure. The vector operations (bind, bundle, cosine) are unchanged. The journal operations (observe, predict, decay) are unchanged. `pmap` is a structural permission — it tells the runtime that the elements are independent.

The monoid is preserved: `(pmap f xs)` produces the same list as `(map f xs)`. Bundle over a pmap result is identical to bundle over a map result. The algebra cannot observe whether its inputs were computed sequentially or in parallel.

## The Simplicity Question

**Is this simple or easy?**

Simple. `pmap` is `map` with a structural annotation. It doesn't complect evaluation order with correctness — the result is identical regardless of execution strategy. It doesn't introduce new data types, new control flow, or new state management. It's a permission, not a mechanism.

**What's being complected?**

Nothing. Sequential `map` promises order AND independence-agnosticism. `pmap` promises independence — the order is explicitly unspecified. This is a de-complection: `pmap` separates "what to compute" from "in what order."

**Could existing forms solve it?**

No. `map` cannot express "these are independent." The runtime has no way to know that the mapped function over observers doesn't share state between invocations. The annotation is the information.

**What about channels?**

Channels (`put!`, `take!`, `select!`) were proposed and rejected (Proposal 001, March 2026). Hickey said: "the heartbeat is your greatest asset. Don't dissolve it." Beckman said: "channels replace a clean categorical structure with an operational model that doesn't compose." `pmap` preserves the fold. The heartbeat remains sequential. The parallelism is within a single fold step, not across steps.

## Rust Compilation Target

```rust
// pmap → rayon::par_iter or std::thread::scope
let observer_vecs: Vec<Vector> = observers.par_iter()
    .map(|obs| {
        let w = obs.window_sampler.sample(encode_count).min(window.len());
        let start = window.len().saturating_sub(w);
        let slice: Vec<Candle> = window.iter().skip(start).cloned().collect();
        thought_encoder.encode_thought(&slice, vm, obs.lens).thought
    })
    .collect();

// pfor-each → rayon::par_iter_mut or std::thread::scope
observers.par_iter_mut()
    .for_each(|obs| obs.journal.decay(decay_rate));
```

## Questions for Designers

1. Is `pmap` the right structural form, or should the parallelism live in the compilation guide rather than the language?
2. Should `pfor-each` exist separately, or should `pmap` with discarded results suffice?
3. Is the safety contract (pure for pmap, disjoint-mutation for pfor-each) expressible in the language, or is it a ward concern?
4. Should `pmap` guarantee result order matches input order, or is unordered acceptable?
5. Does this compose with the fold? The pattern `(fold f init (pmap g xs))` — parallel map, sequential reduce — is the intended idiom. Any concerns?
