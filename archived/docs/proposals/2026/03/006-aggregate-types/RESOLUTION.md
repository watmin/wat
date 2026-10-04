# Resolution: ACCEPTED

Both designers CONDITIONAL. Both conditions met with a framing correction.

## The framing correction

Both designers scoped wat too narrowly — as "the language for the two algebras." This was our fault, not theirs. The `/designers core` skill told them to evaluate against the algebraic primitives. They did exactly what we asked. The skill was wrong.

Wat is the specification of the program. The whole program. The treasury does arithmetic, not algebra. The position lifecycle is a state machine, not a discriminant. The ledger writes SQL, not vectors. These are all enterprise components. They all need to be specified. Wat must be complete — it must name everything the program contains.

The two algebras are the crown jewels. `defrecord` is the setting. Both are needed. A program specification language that can only express algebra leaves half the enterprise dark.

**Action: update the `/propose` and `/designers` skills to recognize three language layers, not one.**

## What the designers agreed on

- `defrecord` is essential (the 16-parameter heartbeat is a specification gap)
- Records are opaque (no destructuring — projections only)
- The compilation model doesn't change
- The algebra files remain untouched

## Where they diverged and how we resolve

### Where does it live?

Hickey: host language layer. Beckman: core, third section.

**Resolution:** New file `core/structural.wat` — the ambient category's product construction. Not in `primitives.wat` (Hickey is right that it's not algebraic). Not in host language (Beckman is right that it's more than `let`). A third core file that says: these forms organize programs. The algebras transform values. The structural forms carry them.

### Access syntax?

Hickey: keywords `(:field record)`. Beckman: dot `(. record field)` as projection.

**Resolution:** Dot. `(. state experts)`. It maps directly to Rust's `state.experts`. Wat → Rust should be transparent. Beckman's categorical argument (projection morphism) is correct, but the pragmatic argument is stronger: the syntax should look like what it compiles to.

### Is `update` core or stdlib?

Hickey: core (essential). Beckman: stdlib (derivable).

**Resolution:** Core, in `structural.wat`. The 12-field reconstruction that `update` prevents is noise that drowns signal. Hickey's argument wins: "its absence forces you to write code where the structural noise exceeds the semantic signal."

## The language structure

```
core/primitives.wat     — two algebras (vector + journal)
core/structural.wat     — program organization (defrecord, projection, update)
std/                    — derived operations on the algebras
Host language           — arithmetic, comparison, control flow (the Lisp substrate)
```

Three layers of core. The algebras don't know about records. Records don't know about algebras. Both are core because both are essential to specifying a program.

## The forms

```scheme
;; core/structural.wat

;; Declare a product type — named fields that travel together.
;; Compiles to a Rust struct. No methods, no mutation.
(defrecord name field1 field2 ...)

;; Project a field — the universal extraction from a product.
;; Compiles to Rust field access: record.field
(. record field) → value

;; Functional update — return a new record with one field changed.
;; Compiles to Rust struct update: Record { field: value, ..record }
(update record :field value) → record
```

## Skill update needed

The `/propose` and `/designers` skills must be updated to recognize three scopes:
- `core/algebra` — the two algebras (highest bar, must be algebraically essential)
- `core/structural` — program organization (must be structurally essential, not algebraic)
- `userland` — application design (uses all of the above)

This prevents future designers from evaluating structural proposals against algebraic criteria.
