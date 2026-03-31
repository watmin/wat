# Resolution: ACCEPTED

Unanimous. Product + coproduct completes the structural layer.

## The form

```scheme
;; Simple enum (keyword variants)
(enum direction :long :short)

;; Tagged enum (variants carry data)
(enum event
  (candle asset candle)
  (deposit asset amount)
  (withdraw asset amount))

;; Match — must be exhaustive
(match (:direction pos)
  :long  (handle-long)
  :short (handle-short))
```

One form. Simple enums are the degenerate case (variants carry no data). Keywords, not atoms — variants are identities, not geometric objects.

Lives in `core/structural.wat` beside `struct`. Product and coproduct are duals.

Match must be exhaustive. The forge checks it. A missing arm on a closed set is a spec violation.

Hickey's guard: variants hold existing structs or scalars, not arbitrary nesting. No full ADT system.
