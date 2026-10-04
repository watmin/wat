# Proposal 011: Derived Fields

**Scope:** structural — a declaration form for computed values on product types.

## 1. The current state

candle.wat uses `(field name computation)` 55 times to declare indicators derived from raw OHLCV data. It is the last phantom rune in the trader lab — 213 started, 1 remains.

```scheme
(field sma20    (sma close 20))
(field rsi      (wilder-rsi close 14))
(field bb-upper (+ sma20 (* 2.0 (stddev close 20))))
```

Each `field` says: "this named value exists on the Candle struct and is computed by this formula." The indicator engine (proposal 004) will implement these as streaming reducers. The wat declares WHAT to compute. The Rust implements HOW.

## 2. The problem

`field` is a phantom. It's not `define` (not a callable function). It's not `struct` (not a standalone type). It's a declaration that extends a struct with a derived value — a field whose value is computed, not stored directly.

Without `field`, candle.wat becomes either:
- 55 `define` functions that nobody calls (the engine calls them implicitly)
- 55 struct fields with no derivation (the formula is lost)
- 55 comments describing computations (prose, not program)

None of these are honest. The `field` form says exactly what it means: "this struct has a field named X, computed from expression Y."

## 3. The proposed change

```scheme
;; Declare a derived field on a struct.
;; The struct must already be declared.
;; The computation is the BUILD-TIME definition.
;; At runtime, it's a pre-computed struct field.
(field struct-name field-name computation)

;; Usage:
(struct raw-candle ts open high low close volume)

(field raw-candle sma20    (sma close 20))
(field raw-candle rsi      (wilder-rsi close 14))
(field raw-candle bb-upper (+ sma20 (* 2.0 (stddev close 20))))
```

The struct name makes the ownership explicit. Field X belongs to struct Y. The computation references other fields by name — the dependency graph is visible.

Compiles to Rust: the struct gains a field, and the indicator engine gains a reducer. The `field` declaration is the specification of both.

## 4. The algebraic question

`field` is not algebraic. It doesn't touch vectors, journals, or cosines. It extends the structural layer — `struct` declares the shape, `field` declares derived values on the shape. Like `update` (functional mutation), `field` operates on structs without entering the algebra.

The dependency between fields (bb-upper depends on sma20) creates a DAG. The indicator engine evaluates fields in dependency order. This is a build-time concern — the wat declares the DAG, the Rust topologically sorts and evaluates it.

## 5. The simplicity question

One form. One concept: "this value is derived from these inputs." Any streaming system has derived fields:
- Market data: indicators from OHLCV
- Sensor networks: derived metrics from raw readings
- Log analytics: computed columns from raw events
- Game state: derived attributes from base stats

The alternative — 55 `define` functions — is accidental complexity. The functions exist only to be called by the engine. They have no callers in user code. They are declarations wearing function syntax.

## 6. Questions for designers

1. **Should `field` name its parent struct?** `(field raw-candle sma20 ...)` vs `(field sma20 ...)`. Naming the struct makes ownership explicit but is verbose when all 55 fields belong to the same struct.

2. **Should fields reference other fields by name?** `(field raw-candle bb-upper (+ sma20 ...))` implies `sma20` is resolved from the same struct. This creates a DAG. Is implicit field reference acceptable, or should it be explicit: `(+ (:sma20 self) ...)`?

3. **Does `field` belong in `core/structural.wat`?** It operates on structs. But it's closer to a build-time macro than a runtime form. Struct and enum are runtime types. Field is a compile-time declaration.

4. **Is this the streaming indicator engine's `define`?** Proposal 004 describes per-indicator reducers. `field` might BE the reducer declaration. If so, should the proposal wait until proposal 004 is implemented, so the form is proven in practice?
