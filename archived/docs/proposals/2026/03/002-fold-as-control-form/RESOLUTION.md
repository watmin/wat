# Resolution: Proposal 002 — Fold as Control Form

Status: **ACCEPTED**

Both designers accepted.

## The decision

Add `fold` to the wat language as a control form alongside `map`, `filter`, `for-each`, `filter-map`.

```scheme
(fold step-fn initial-state items)   ; (state, element) → state
```

## Designer verdicts

**Hickey: ACCEPTED.** The key distinction from Proposal 001: `defprocessor` was the callee declaring "I am a reducer." `fold` is the caller saying "reduce this function over this stream." The function stays ignorant. The agency moved from callee to caller.

**Beckman: ACCEPTED.** `fold` is the catamorphism that was always there unnamed. The journal IS a fold. The heartbeat IS a fold. Naming it makes the self-similarity visible across levels.

## What changes

- `LANGUAGE.md`: `fold` added to Control Forms → Iteration section.
- Journal documentation should note that journal is a specialized, encapsulated fold (Beckman's refinement).

## Constraints (from Hickey)

1. `fold` is a control form, not a seventh primitive.
2. Step functions are plain `define` — no special annotations.
3. No runtime/deployment semantics. `fold` is algebra, deployment is operations.
