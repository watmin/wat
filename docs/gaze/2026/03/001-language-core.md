# Gaze Report: Wat Language Core

*First gaze. 2026-03-30.*

## Summary

| File | Spark | Issues |
|------|-------|--------|
| `core/primitives.wat` | High | Stale header counts |
| `std/vectors.wat` | High | Domain-specific BUY/SELL comment in generic stdlib |
| `std/scalars.wat` | Perfect | None |
| `std/memory.wat` | High | None |
| `std/patterns.wat` | Mixed | Dead `curve` parameter; phantom `unbind` |
| `std/common.wat` | Solid | Missing `open` in open/active/closed triple |
| `LANGUAGE.md` | High | Three drift points vs actual .wat files |
| `examples/enterprise.wat` | Crown jewel | `candle-idx` unbound; `channels-ind` mumbles; `observe` missing args |

## Findings

### Cross-file inconsistencies (highest priority)

1. **Stale count in primitives.wat header** — says "five generators, nine forms"; actual count is six primitives and eleven forms.
2. **`similarity-profile`, `noise-floor`, `sweet-spot`** exist in LANGUAGE.md but not in any .wat file.
3. **`gate` return type** — LANGUAGE.md says Bool, patterns.wat returns a Vector (bundle with annotation).
4. **`unbind`** used in patterns.wat comment but never defined anywhere.
5. **`nothing`** used in enterprise.wat but never defined in core or stdlib.

### Per-file findings

**primitives.wat** — Header says "five generators, nine forms" but file defines six primitives and eleven forms. Journal coalgebra section header says "5 forms" but defines 6-7 depending on whether `register` counts. Fix the counts or drop them — counts age badly.

**vectors.wat** — Line 7: "BUY = atom, SELL = (permute atom 1). Orthogonal in hyperspace." Domain-specific trading commentary in domain-agnostic stdlib. Should say: "Orthogonal encoding of ordered alternatives."

**scalars.wat** — Perfect. Nothing to add, nothing to remove.

**memory.wat** — Clean. The Template 1/Template 2 framing connecting stdlib to core is excellent.

**patterns.wat** — Two bugs: (1) `curve` parameter declared but unused — the body calls core `(curve journal)` directly. (2) `unbind` used in consumer examples but never defined (bind is self-inverse so unbind IS bind, but the name doesn't resolve).

**common.wat** — Missing `(atom "open")` in what should be the open/active/closed triple. Minor predicate grouping question.

**LANGUAGE.md** — Three phantom operations (`similarity-profile`, `noise-floor`, `sweet-spot`) listed but never defined. Gate return type wrong (says Bool, should be Vector). These erode trust in the reference.

**enterprise.wat** — Crown jewel of the wat codebase. Seven layers read top-to-bottom as the architecture. Closing poem earns its newlines. Minor: `candle-idx` appears unbound, `channels-ind` name mumbles, one `observe` call missing label+weight args.

## What shines

- The six primitives are perfectly named. Not one needs renaming.
- scalars.wat is the platonic ideal of a stdlib file.
- The enterprise example reads as the architecture itself.
- The gate comment: "The message always flows. The consumer decides what credibility means."
- LANGUAGE.md's "What Wat Is Not" / "What Wat Is" could sell the language to a stranger.
