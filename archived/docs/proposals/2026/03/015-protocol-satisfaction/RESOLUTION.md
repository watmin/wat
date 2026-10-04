# Resolution: ACCEPTED — Option A (explicit, exhaustive)

Unanimous. Both designers say: explicit mapping, exhaustive satisfaction.

## The decision

One `satisfies` per (struct, protocol) pair. All protocol functions
mapped. No convention-based inference. No partial satisfaction.

```scheme
(defprotocol indicator
  (step [state input] "Advance. Returns (state, output).")
  (ready? [state] "Warmed up?")
  (reset [state] "Return to initial state."))

(satisfies sma-state indicator
  :step    sma-step
  :ready?  sma-ready?
  :reset   sma-reset)
```

Multiple protocols = multiple `satisfies`:

```scheme
(satisfies sma-state indicator
  :step    sma-step
  :ready?  sma-ready?
  :reset   sma-reset)

(satisfies sma-state serializable
  :serialize   sma-serialize
  :deserialize sma-deserialize)
```

## Rules

1. **Exhaustive.** Every protocol function must be mapped. Missing = error.
2. **One instance per pair.** At most one `satisfies` per (struct, protocol).
   Duplicate = error.
3. **Explicit only.** No convention-based inference. The mapping IS the spec.
4. **Separate from struct.** The `satisfies` block lives after the struct
   and the implementing functions. Behavior is not data.

## Why not convention

The codebase already violates its own naming: `new-sma` vs `sma-step`
vs `sma-ready?`. Convention would require special cases that compound
into an undocumented type system. Three explicit lines cost less than
debugging silent inference failures.

## Why exhaustive

Hickey: partial satisfaction is subtyping — not proposed, don't smuggle it.
Beckman: a partial witness is not a witness. If partial is needed, propose
protocol extension separately.
