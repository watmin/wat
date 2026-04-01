# Resolution: ACCEPTED — Model C (structural absence)

The datamancer overruled both designers. Neither Model A nor Model B.

Hickey was right: the compiler should infer, the specifier shouldn't
think about Rust types. Beckman was right: bool and Option are distinct
constructions that shouldn't blend. Both were wrong about the mechanism.

## The decision

**`true` / `false`** — boolean literals. Added to host language.

**No `nil`.** Absence is structural, not a value. Rust has no nil.
Wat shouldn't pretend it does.

**Absence is expressed by `when` not executing.** The compiler sees
a function whose body is `(when ...)` or `(cond ...` without else)
and generates `Option<T>`. The specifier writes natural control flow.
The compiler recovers the types.

**`?` on struct field names** for fields that start absent:

```scheme
(struct side-state
  latest?         ; Option<Candle> — starts absent, populated later
  age
  staleness)
```

One character. One convention. The compiler generates `Option<T>`
for `?` fields and initializes to `None` when not provided.

## What this replaces

- `#f` in option-returning branches → `when` (don't enter the block)
- `#f` for boolean fields → `false`
- `nothing` (bare atom) → gone. Absence is structural.
- `nil` → never existed. Never will.

## The forms stay clean

```scheme
(define (tick pos price k-trail)
  (when (!= (:phase pos) :closed)
    (match (:direction pos)
      :long (cond ((<= price (:trailing-stop pos)) :stop-loss)
                  ((>= price (:take-profit pos))    :take-profit))
      :short (cond ((>= price (:trailing-stop pos)) :stop-loss)
                   ((<= price (:take-profit pos))    :take-profit)))))
```

No type annotations. No nil. No Option. Just `when`.

## Compiler obligations

A future wat-to-Rust compilation guide should document:
- `(when ...)` as function body → `Option<T>` return type
- `(cond ...` without else) → `Option<T>` return type
- `field?` in struct → `Option<T>` field, initialized to `None`
- `(when-let ((x expr)) body)` → `if let Some(x) = expr { body }`
- `true`/`false` → `bool`
