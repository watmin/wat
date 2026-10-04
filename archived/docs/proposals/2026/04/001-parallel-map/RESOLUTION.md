# Resolution: Proposal 001 — Parallel Map

**Decision:** ACCEPTED  
**Date:** 2026-04-03

## The Tension

Hickey: CONDITIONAL. Independence is already expressed by purity. The compiler can see it. Optimization hints belong in the compilation guide, not the grammar. Adding `pmap` creates a split world where every `map` becomes a decision point.

Beckman: APPROVED. Independence is undecidable to infer in general. The programmer knows. `pmap` is a natural transformation — the algebra cannot observe whether inputs were computed sequentially or in parallel. The information belongs in the program.

## The Resolution

Beckman is right. Be explicit. If something is parallel, say so in the specification.

The wat is a specification language. It specifies what the enterprise does. If the specification says `map`, the reader assumes sequential. If the specification says `pmap`, the reader knows the elements are independent and the runtime may parallelize. This is information about the program's structure, not an optimization hint. The programmer knows their observers are independent. The specification should say so.

Hickey's concern about the "split world" is valid but manageable. The rule is simple: if the elements are independent and the function is pure, use `pmap`. If not, use `map`. This is not a tax on every reader — it's a declaration that communicates structure. The same way `struct` communicates "this is a product type" and `enum` communicates "this is a sum type," `pmap` communicates "these elements are independent."

Hickey's point about `pfor-each` and disjoint mutation is the strongest objection. The language can't fully verify disjointness. Accepted — the ward checks what it can (mutations root at the lambda parameter), and the programmer asserts the rest. This is the same trust model as `set!` — the language trusts the programmer to mutate responsibly.

The `#:parallel` annotation alternative was considered. Rejected — annotations are invisible to the structure. A reader scanning the wat for parallelism points should see `pmap`, not hunt for metadata tags. The form IS the annotation.

## What's Accepted

1. `pmap` — parallel map. Semantically identical to `map`. Pure functions only. Ward-enforced purity check. Result order preserved.

2. `pfor-each` — parallel for-each. Semantically identical to `for-each`. Disjoint mutations only. Ward checks what it can, programmer asserts the rest.

3. No `pfold`. Associativity is not syntactically checkable.

4. `pmap` is a permission, not a directive. The runtime may evaluate sequentially if parallelism would not improve throughput.

5. Result order is preserved. Non-negotiable.

## What Changes in LANGUAGE.md

Add to the Host Language iteration section:

```scheme
(pmap f xs)          → list    ; parallel map — f must be pure, result order preserved
(pfor-each f xs)     → ()      ; parallel for-each — disjoint mutations only
```

## What Changes in the Enterprise Wat

The sites identified in the proposal switch from `map`/`for-each` to `pmap`/`pfor-each` where independence holds.
