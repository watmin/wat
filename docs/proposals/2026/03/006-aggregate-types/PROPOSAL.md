# Proposal 006: Aggregate Types

**Scope:** core — a new form in the wat language.

## 1. The current state

Wat has two algebras (vector, journal), a stdlib, and host language forms. It has no way to declare that a set of values belong together. Every function that needs multiple values takes them as individual parameters.

The enterprise heartbeat takes 16 parameters. The treasury-execute takes 7. Both have runes inscribed: `rune:gaze(length) — wat has no aggregate types`. The gaze found the gap. The runes prove it's not code quality — it's a missing language form.

## 2. The problem

You cannot thread state through a fold without naming the state.

The enterprise is a fold: `(state, event) → state`. In Rust, the state is `EnterpriseState` — one struct, one parameter to `on_event`. In wat, the state is 16 individual parameters because the language cannot say "these belong together."

This affects every function that touches enterprise state:
- `heartbeat` — 16 parameters (the full state)
- `treasury-execute` — 7 parameters (subset of state + context)
- `learn` — 6 parameters (another subset)
- `manage-positions` — 4 parameters

The state IS one thing. The language forces it to be many things.

## 3. The proposed change

A new core form: `defrecord`.

```scheme
;; Declaration
(defrecord enterprise-state
  experts generalist manager risk treasury
  positions exit-expert pending band ledger
  last-exit-price last-exit-atr)

;; Construction
(enterprise-state
  :experts experts
  :generalist generalist
  :manager manager
  ...)

;; Field access
(. state experts)           ; → the experts value
(. state last-exit-price)   ; → the last exit price

;; The heartbeat becomes:
(define (heartbeat candle-idx candle vector-manager state)
  (let* ((expert-preds (map (lambda (e) (e candle)) (. state experts)))
         ...)
    (update state :last-exit-price new-price)))

;; Update (functional — returns a new record)
(update state :field new-value)
```

### What defrecord IS

A compile-time declaration that a set of named fields form one value. No methods. No inheritance. No mutation. A product type — the simplest aggregate.

In Rust, it compiles to a `struct` with named fields. In the wat spec, it's documentation that these values travel together.

### What defrecord is NOT

- Not a class. No methods, no `self`, no dispatch.
- Not mutable. `update` returns a new record (functional update).
- Not an extension to the algebra. Records don't bind, bundle, or cosine. They carry state through the fold.

## 4. The algebraic question

Does `defrecord` compose with the existing two algebras?

Records carry values. Vectors are values. Journals are values. Labels are values. Records can carry all of them. A record is a product type — `A × B × C × ...` — which is the simplest categorical construction. Product types compose with everything because they compose with nothing — they just hold things.

The fold becomes: `(Record, Event) → Record`. The record IS the carrier. The fold step reads fields, computes, and returns a new record with updated fields. This is the standard functional fold over a product type.

Records don't interact with the vector algebra. You don't bind a record or bundle records. You pass records as state and extract fields as needed. The algebras operate on vectors. Records operate on program state. These are orthogonal concerns.

## 5. The simplicity question

Is `defrecord` simple or easy?

**Simple:** It adds one concept (named product type) with three operations (construct, access, update). It doesn't complect with anything — records are not vectors, not journals, not labels.

**Not easy:** It adds syntax. A new form. A new way to declare things. Every new form has a learning cost.

**The alternative:** Continue using individual parameters. This is simpler (no new form) but not simple (the heartbeat's 16 parameters are complected — they are one thing pretending to be many).

Hickey's test: "Is it complecting something that was simple?" No. The heartbeat was already complected — 16 parameters interleaving state and context. `defrecord` untangles it by naming the aggregate.

## 6. Questions for designers

1. **Is this a primitive or a convenience?** Can existing forms express aggregate types? `bundle` aggregates vectors, but not journals or scalars. `let` binds names, but doesn't declare that names belong together. Is there a composition of existing forms that serves as a record?

2. **What is the access syntax?** `.` (dot access), keyword access (`:field record`), or function access (`(field record)`)? Each has tradeoffs. Dot is familiar from Rust/Java. Keywords are Clojure. Function access is pure Lisp but ambiguous.

3. **Should records be opaque?** Can you pattern-match on record fields? Or is the record a black box where only the declared accessors work? Opaque records enforce encapsulation. Open records enable destructuring.

4. **Does this change the compilation model?** Currently wat compiles to Rust via human translation. A `defrecord` could generate a Rust `struct` declaration. Does this push wat toward being a real compiler, or is it still a specification language?

5. **Is `update` essential?** Functional update (`(update state :field value)`) is convenient but derivable — you can construct a new record with one field changed. Is the convenience worth the form?

6. **Where does it live?** Is `defrecord` a core form (alongside atom, bind, bundle) or a stdlib form (derived from something more primitive)? Records are not algebraic — they don't participate in the vector or journal algebras. They're structural. Does structural belong in core?
