# Proposal 012: Multi-Field Update

**Scope:** structural — extending the existing `update` form.

## 1. The current state

`(update record :field value)` changes one field. To change three fields:

```scheme
(update (update (update treasury
  :balances (assoc (:balances treasury) from (- (balance treasury from) spend)))
  :balances (assoc (:balances treasury) to   (+ (balance treasury to) received)))
  :total-fees-paid (+ (:total-fees-paid treasury) fee))
```

Three nested parentheses. Each `update` wraps the previous. The inner updates return intermediate records that the outer updates consume. The nesting grows linearly with the number of fields changed.

Treasury's `swap` changes 3 fields. `close-position` changes 4. The enterprise fold's state transitions change 5-10 fields per step. At 10 fields, the nesting is unreadable.

## 2. The problem

The Rust says:
```rust
self.balances.insert(from, balance_from - spend);
self.balances.insert(to, balance_to + received);
self.total_fees_paid += fee;
```

Three flat statements. The wat says:
```scheme
(update (update (update treasury ...) ...) ...)
```

Three nested expressions. The wat is harder to read than the Rust it specifies. A specification language should be CLEARER than the implementation, not more obscure.

## 3. The proposed change

Extend `update` to accept multiple field-value pairs:

```scheme
;; Current (one field)
(update record :field value) → record

;; Proposed (multiple fields)
(update record :field1 value1 :field2 value2 :field3 value3) → record
```

The semantics: apply all field changes to one record, return the new record. Equivalent to nested single-field updates but flat. The fields are applied left-to-right — later fields see the original record, not intermediate updates.

Treasury swap becomes:
```scheme
(update treasury
  :balances       (assoc (:balances treasury) from (- (balance treasury from) spend))
  :total-fees-paid (+ (:total-fees-paid treasury) fee))
```

One expression. Flat. Readable. The Rust compiles it to sequential field assignment.

## 4. The algebraic question

This is a syntactic extension, not an algebraic one. Multi-field `update` is sugar for nested single-field `update`. The semantics are identical. No new algebraic structure is introduced.

The product type's universal property (projections) is preserved. Each field is still accessed by keyword. The update still returns a new record.

## 5. The simplicity question

The alternative is the status quo: nest `update` calls. This works. It's correct. It's ugly. The question is whether "ugly but correct" is acceptable in a specification language whose purpose is clarity.

Multi-field `update` is strictly simpler to read. It doesn't add a new concept — `update` already exists. It extends the arity. Like `bundle` taking varargs instead of requiring nested binary calls.

## 6. Questions for designers

1. **Should later fields see intermediate state or the original?** `(update r :a 1 :b (:a r))` — does `:b` get the old `:a` or the new `1`? If original: pure parallel assignment. If intermediate: sequential, order matters.

2. **Does this belong in `core/structural.wat` or is it stdlib sugar?** Single-field update is core. Multi-field is a variadic extension. `bundle` is variadic in core. Precedent exists.

3. **Is there a better form?** Clojure uses `(assoc m :a 1 :b 2 :c 3)`. Haskell uses record update syntax `r { a = 1, b = 2 }`. Should wat follow either convention?
