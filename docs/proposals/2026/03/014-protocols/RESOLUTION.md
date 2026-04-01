# Resolution: ACCEPTED — check-only protocols

Both designers conditional. Both say check-only, not dispatch. Both say
separate implementation, not inline. Both say retire (field ...).

Beckman names what this is: a type class. The third construction in
the ambient category alongside struct (product) and enum (coproduct).

Hickey names the Rust mapping: defprotocol → trait. satisfies → impl.
The protocol evaporates into something the Rust compiler enforces.

## The decision

### defprotocol

Declares a set of function signatures. Check-only — no dispatch.

```scheme
(defprotocol indicator
  "A scalar stream processor. State in, state out."
  (step [state input] "Advance by one input. Returns (state, output)."))
```

### satisfies

Declares that a struct satisfies a protocol. Separate from the struct.

```scheme
(struct sma-state buffer period)

(satisfies sma-state indicator
  :step sma-step)
```

The forge checks: does sma-step exist? Does it take a sma-state as
first argument? Does it return a pair? The Rust compiler enforces
the trait implementation.

### Rust mapping

```
(defprotocol indicator ...)  →  trait Indicator { fn step(...) -> ...; }
(satisfies sma-state indicator :step sma-step)  →  impl Indicator for SmaState { ... }
```

Added to docs/COMPILATION.md.

### What this retires

`(field struct-name field-name computation)` — proposal 011.
Protocols subsume it. One in, one out. Same commit.

### What this does NOT add

- No dispatch. Call `sma-step` by name. Dispatch is a separate
  proposal if needed (Beckman: it's a different categorical construction).
- No inline implementation. Struct is a product type. Behavior is separate.
- No return types. Arity checking only. Type system earns its way uniformly.
- No reify (anonymous implementations). Named structs only for now.
