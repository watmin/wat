# Proposal 004: Journal Operations — Core or Stdlib?

Status: **DRAFT**

Follows from: Proposal 003 Resolution (unresolved tension)

---

## 1. The Current State

The journal primitive in `core/primitives.wat` creates opaque state:

```scheme
(journal name dims recalib-interval) → Journal
```

Three operations on that state live in `std/journal.wat`:

```scheme
(observe journal thought label weight)
(predict journal thought) → Prediction
(decay journal rate)
```

This placement follows the Proposal 003 interim decision: implement Hickey's position (stdlib), then revisit. The file itself documents the tension in its header comment.

The six core primitives are: `atom`, `bind`, `bundle`, `cosine`, `journal`, `curve`.

## 2. The Problem

The stdlib contract says: forms in `std/` are expressible as compositions of the six core primitives plus syntax. If `observe`, `predict`, and `decay` cannot be so expressed, they violate the contract by living in `std/`. If they can be so expressed, they belong there. The question is precise and answerable.

The tension from Proposal 003:

- **Hickey**: observe is bundle-into-accumulator, predict is cosine-against-discriminant, decay is scalar-multiply. These are compositions. Stdlib.
- **Beckman**: the journal is opaque. You cannot reach the accumulators with bundle. You cannot reach the discriminant with cosine. The opacity makes these co-generators of a coalgebra. Core.

Both are correct about different things. The question is which property governs placement.

## 3. The Analysis

### Can observe be implemented from the six primitives alone?

No. Here is why.

Suppose we attempt to define `observe` in terms of the six primitives:

```scheme
;; Hypothetical stdlib observe:
(define (observe journal thought label weight)
  ;; We need to bundle `thought` into journal's accumulator for `label`.
  ;; But: which accumulator? journal is opaque. There is no form that
  ;; extracts an accumulator from a journal.
  ;;
  ;; (bundle (??? journal label) (??? thought weight))
  ;;
  ;; The ??? is the problem. No primitive provides read or write
  ;; access to journal internals.
  )
```

The six primitives provide:
- `atom` — creates vectors from names
- `bind` — composes two vectors
- `bundle` — superimposes vectors
- `cosine` — measures similarity between two vectors
- `journal` — creates opaque state (constructor only)
- `curve` — reads accuracy/conviction relationship from a journal

None of these gives write access to a journal's accumulators. `bundle` operates on vectors, not on journal internals. `cosine` measures two vectors, not a vector against a hidden discriminant. The journal constructor returns a sealed container. Without a way to open it, no composition of the six primitives can feed observations into it.

The same argument applies to `predict` and `decay`:
- `predict` needs read access to the journal's discriminant vector. No primitive exposes it.
- `decay` needs write access to the journal's accumulators to scale them. No primitive provides it.

### What Hickey's argument actually shows

Hickey is correct that the *algorithms* decompose: observe is conceptually bundle, predict is conceptually cosine, decay is conceptually scalar multiply. The mathematical operations inside the journal are compositions of vector algebra.

But the *access* does not decompose. The journal's opacity means the composed operations cannot be expressed as wat expressions over the six primitives. The algorithms are derivable. The implementations are not.

### The coalgebra argument

Beckman's framing is precise. A coalgebra has:
- A state space (the journal's internal accumulators, discriminant, recalib counter)
- Observations that map external inputs to state transitions (`observe`)
- Projections that map state to external outputs (`predict`)
- Endomorphisms on state (`decay`)

The constructor (`journal`) and these three operations form a single algebraic unit. The constructor without the operations is a box you cannot open. The operations without the constructor have nothing to operate on. They are not separable.

`curve` is also a projection from journal state (it reads the accuracy history). It already lives in core. If `curve` is core because it reads journal internals, `predict` is core for the same reason. The current placement is inconsistent: `curve` in core, `predict` in stdlib, both reading opaque journal state.

## 4. The Proposed Change

Move `observe`, `predict`, and `decay` from `std/journal.wat` to `core/primitives.wat`.

The journal section of core becomes:

```scheme
;; The state monad of the algebra.
;; Constructor + co-operations form a single coalgebra.

(journal name dims recalib-interval) → Journal

(observe journal thought label weight)
(predict journal thought) → Prediction  ; { direction, conviction, raw-cos }
(decay journal rate)

(curve journal resolved) → (a, b)
```

`std/journal.wat` is retired. Its contents move to core.

The primitive count changes from "six primitives" to "six primitives, nine forms":
- Four vector algebra generators: `atom`, `bind`, `bundle`, `cosine`
- One coalgebra (five forms): `journal`, `observe`, `predict`, `decay`, `curve`

The *generator* count is still six. The form count is nine. The distinction matters: `observe`/`predict`/`decay` are not independent generators. They are the interface of the `journal` generator. They add no new algebraic structure — they complete an existing one.

## 5. The Algebraic Question

Does this compose with the existing algebra?

Yes. The journal coalgebra is already present. This proposal does not add it — it acknowledges that it was always a single unit. The four vector primitives (`atom`, `bind`, `bundle`, `cosine`) remain unchanged. The journal coalgebra (`journal`, `observe`, `predict`, `decay`, `curve`) remains unchanged. Only the file boundary moves.

Does this introduce a new algebraic structure?

No. The coalgebra was introduced when `journal` was made a primitive. `observe`, `predict`, and `decay` are part of that same structure. Moving them to core is recognizing what already exists, not adding something new.

## 6. The Simplicity Question

**Is this simple or easy?**

Simple. It removes a false separation. Currently, one algebraic unit is split across two layers. The split forces `std/journal.wat` to have "privileged access" to core internals — a concept that exists nowhere else in the language. Removing the split removes the special case.

**What's being complected?**

The current design complects two ideas: "stdlib means derivable from primitives" and "these operations need special compiler support." Those are contradictory. If an operation needs compiler support to access opaque state, it is not derivable from the public primitives. Calling it stdlib while giving it special access is a polite fiction.

**Could existing primitives solve it?**

Only if the journal were not opaque. If `journal` exposed its accumulators as vectors — say, `(journal-accumulator journal label) → Vector` — then `observe` could be written as:

```scheme
(define (observe journal thought label weight)
  (bundle (journal-accumulator journal label) thought weight))
```

But exposing accumulators would break encapsulation. The journal's value is that it manages its own state: recalibration intervals, discriminant computation, accumulator normalization. Exposing internals would push state management to userland, duplicating logic and creating correctness risks.

The opacity is a deliberate design choice. The consequence of that choice is that operations on opaque state must live where the opacity is defined: core.

## 7. Questions for Designers

1. **The consistency argument.** `curve` reads journal internals and lives in core. `predict` reads journal internals and lives in stdlib. Is there a principled reason for this asymmetry, or is it an accident of history?

2. **The naming.** If journal operations move to core, should `core/primitives.wat` remain one file, or should it split into `core/algebra.wat` (atom, bind, bundle, cosine) and `core/journal.wat` (journal, observe, predict, decay, curve)?

3. **The precedent.** If `observe`/`predict`/`decay` move to core because they access opaque state, does any future opaque container (e.g., a hypothetical `online-subspace` primitive) automatically bring its operations into core? Is "operations on opaque state are core" the general rule?

4. **The count.** The language has described itself as having "six primitives." Moving to "six primitives, nine forms" changes the tagline. Does this matter? Is the correct framing "six generators" (four algebra + one coalgebra + one evaluator) with the coalgebra having a constructor and three co-operations?
