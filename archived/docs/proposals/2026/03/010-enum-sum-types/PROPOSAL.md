# Proposal 010: Enum (Sum Types)

**Scope:** structural — the complement of struct (product types).

## 1. The current state

Wat has `struct` (product types) — named fields that travel together. It does NOT have `enum` (sum types) — finite alternatives where exactly one is active. The enterprise uses sum types extensively:

- `Direction`: `:long` | `:short`
- `Phase`: `:observe` | `:tentative` | `:confident`
- `ExitReason`: `:trailing-stop` | `:take-profit` | `:horizon-expiry`
- `PositionPhase`: `:active` | `:runner` | `:closed`
- `PositionExit`: `:stop-loss` | `:take-profit`
- `Event`: `Candle` | `Deposit` | `Withdraw`
- `EnrichedEvent`: `Candle` | `Deposit` | `Withdraw`
- `Fact`: `Zone` | `Comparison` | `Scalar` | `Bare`
- `LogEntry`: 9 variants

Without `enum`, journal.wat invents `(variants Long Short)` — a phantom form. Position.wat uses bare keywords (`:long`, `:short`) without declaring the closed set. The forge found three `_ =>` wildcard matches in position.rs that would silently catch a third Direction variant.

## 2. The problem

Sum types are the complement of product types. Products say "all of these together." Sums say "exactly one of these." A language with products but no sums can name aggregates but cannot name alternatives.

The enterprise needs both:
- `(struct managed-position id entry-price ...)` — all fields present
- `(enum direction :long :short)` — exactly one active

Without `enum`, alternatives are informal. Keywords like `:long` and `:short` float without a declaration that these are the ONLY options. A reader cannot know the closed set. The compiler (Rust) cannot verify exhaustiveness. The forge cannot check that match arms cover all variants.

## 3. The proposed change

```scheme
;; Simple enum (keyword variants, no associated data)
(enum direction :long :short)

(enum phase :observe :tentative :confident)

(enum exit-reason :trailing-stop :take-profit :horizon-expiry)

;; Match on enum
(match (:direction pos)
  :long  (- current-price (:entry-price pos))
  :short (- (:entry-price pos) current-price))
```

For enums with associated data (like Event, Fact, LogEntry):

```scheme
;; Tagged enum (variants carry data)
(enum event
  (candle asset candle)
  (deposit asset amount)
  (withdraw asset amount))

(enum fact
  (zone indicator zone-name)
  (comparison predicate a b)
  (scalar indicator value scale)
  (bare label))

;; Match with destructuring
(match event
  (candle asset candle)   (process-candle asset candle)
  (deposit asset amount)  (deposit treasury asset amount)
  (withdraw asset amount) (withdraw treasury asset amount))
```

## 4. The algebraic question

Struct is the product construction in the ambient category. Enum is the coproduct (sum). Together they give the category's universal constructions — the ability to aggregate (product) and to choose (coproduct). This completes the structural layer.

Enums do not interact with the vector algebra. You don't bind an enum or bundle enums. Enums carry values through the fold — just like structs. They are structural, not algebraic.

## 5. The simplicity question

Two forms: `enum` (declare the alternatives) and `match` (dispatch on them).

`match` already exists in the host language. The new contribution is `enum` — a declaration that a name has exactly these variants and no others. The Rust compiler already enforces this. The wat should be able to express it.

Without `enum`, every match on a keyword is open — any keyword could appear. With `enum`, the set is closed. The specification says "these are the options." Closed sets prevent bugs.

## 6. Questions for designers

1. **Simple vs tagged?** Should `enum` support both simple keywords AND variants with associated data? Or should these be two different forms?

2. **Where does it live?** `core/structural.wat` alongside `struct`? Product and coproduct are the two universal constructions.

3. **Does match need to be exhaustive?** In Rust, non-exhaustive match is a warning/error. In wat (a spec language), should the spec DECLARE that all variants are handled? Or is this the compiler's job?

4. **Naming convention.** Rust uses `PascalCase` for variants. Wat uses `:keywords`. Should enum variants be keywords (`:long`, `:short`) or atoms (`(atom "long")`)? Keywords are values. Atoms are vectors. Enum variants are identities, not geometric objects.
