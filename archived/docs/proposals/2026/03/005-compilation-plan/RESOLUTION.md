# Resolution: Proposal 005 — Compilation Plan

Status: **ACCEPTED**

Both designers accept. The plan is right. The phasing is right.

## The plan

**Phase 1 (blocking):** Move journal coalgebra from trading lab to holon-rs.
- N-ary labels (not binary Buy/Sell) — journal takes a list of label names at construction
- Accumulators MUST be private — opacity is the foundation of the coalgebra argument (Proposal 004)
- Hickey: N accumulators, max-cosine prediction across N
- Beckman: Positive/Negative naming to make discriminant asymmetry visible

**Phase 2:** Document the compilation table — every wat form to its holon-rs type and method.

**Phase 3:** Audit holon-rs surplus operations. Stdlib expressibility test: can it be composed from the nine core forms? If not, it's either a new primitive or an unnamed utility.

## Designer consensus

- The functor from wat to holon-rs exists and is well-defined for the algebra. Phase 1 repairs the break on the journal fragment.
- The journal in holon-rs must have private accumulators. If public, observe becomes stdlib and the entire core-primitive justification collapses.
- N-class generalization is correct — the trading lab's binary discriminant is the first application, not the definition.
- curve belongs with the journal in holon-rs (same module, same opacity boundary).

## What to implement first

1. Promote journal to holon-rs with N-ary labels and private accumulators
2. The trading lab becomes a consumer of holon-rs Journal, not the owner
3. Document the compilation table in wat/docs/
