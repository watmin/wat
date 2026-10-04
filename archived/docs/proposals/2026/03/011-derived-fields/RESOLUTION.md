# Resolution: ACCEPTED

Both designers accept. One tension resolved.

## The form

```scheme
(field struct-name field-name computation)
```

- Name the parent struct (unanimous — explicit over implicit)
- Unqualified sibling field references (unanimous — `sma20` not `(:sma20 self)`)
- Lexical ordering required — no forward references (Hickey)
- Circular dependencies are static errors (Beckman)

## Where it lives

Hickey: `std/` — build-time declaration, not runtime type.
Beckman: `core/structural.wat` — operates on product types.

**Resolution:** `std/fields.wat` — a derived pattern over structs, like `gate` is a derived pattern over the algebra. `field` declares what to compute. `struct` declares the shape. They're related but `field` is a higher-level concept.

## Ship now

Both agree: don't wait for proposal 004. The 55 uses in candle.wat are the evidence. The specification is independent of the streaming indicator engine.
