# Resolution: ACCEPTED

Both designers CONDITIONAL. Both conditions met. One override.

## The syntax

```scheme
;; Declare
(struct enterprise-state
  experts generalist manager risk treasury
  positions exit-expert pending band ledger
  last-exit-price last-exit-atr)

;; Access — keyword as function
(:experts state)

;; Construct — named fields
(enterprise-state
  :experts experts
  :generalist generalist
  :treasury treasury)

;; Functional update — new record, one field changed
(update state :last-exit-price new-price)
```

## Decisions

### Form name: `struct`
Unanimous. Rust's word. No `def` prefix. No heritage baggage.

### Field types: untyped
Override on Beckman (who wanted mandatory types for compilation). Hickey wins: bare symbols cannot be wrong. Wat's own LANGUAGE.md says "Types are documentation, not enforcement." The Rust struct is the source of truth for types. The wat struct is the source of truth for shape.

### Access: keyword as function `(:field record)`
Hickey's choice. Keywords read like English: "experts of state." One syntax for construction, access, and update. The Rust compiler translates to `state.experts` — that's its job.

### Construction: named only
Unanimous. Positional complects field identity with field position.

### Update: keyword syntax `(update record :field value)`
Unanimous. Keywords distinguish field names from values.

### Nesting: no sugar
Unanimous. `(:balance (:treasury state))` composes naturally. No `..` form.

## The three forms

| Form | Purpose | Compiles to |
|------|---------|-------------|
| `(struct name field1 field2 ...)` | Declare product type | `struct Name { field1: T, ... }` |
| `(:field record)` | Project a field | `record.field` |
| `(update record :field value)` | Functional update | `Name { field: value, ..record }` |
