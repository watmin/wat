# Proposal 015: Protocol Satisfaction Mechanics

## Scope: structural

## Builds on: proposal 014 (protocols)

## Problem

Proposal 014 accepted `defprotocol` + `satisfies` but left the
satisfaction mechanics underspecified. Three open questions:

1. A protocol with multiple functions — does `satisfies` map them
   all in one declaration, or one `satisfies` per function?

2. A struct satisfying multiple protocols — one `satisfies` per
   protocol, or one `satisfies` listing all protocols?

3. Explicit mapping (`:step sma-step`) vs convention-based
   (the forge infers `sma-step` satisfies `step` by naming and arity)?

## Current state (from 014)

```scheme
(defprotocol indicator
  (step [state input] "Advance by one input."))

(satisfies sma-state indicator
  :step sma-step)
```

This works for one function. What happens with more?

## Option A: Variadic satisfies (explicit mapping)

One `satisfies` per (struct, protocol) pair. All mappings inside.

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

Pros: explicit, no guessing, maps to Rust `impl Trait for Struct { ... }`.
Cons: the mapping table (`:step sma-step`) is boilerplate when naming
is predictable.

## Option B: Convention-based (implicit mapping)

The forge infers the mapping from naming convention. If the protocol
declares `step`, and `sma-step` exists with `sma-state` as first param,
the forge binds them.

```scheme
(defprotocol indicator
  (step [state input])
  (ready? [state])
  (reset [state]))

(satisfies sma-state indicator)    ;; no mapping — forge infers
;; forge finds: sma-step, sma-ready?, sma-reset
;; checks arity, first param type
```

Convention: `{struct-prefix}-{protocol-fn-name}`.
`sma-state` → prefix `sma`. Protocol fn `step` → looks for `sma-step`.

Pros: zero boilerplate. Convention is discoverable.
Cons: implicit. Naming must be disciplined. Non-obvious which function
satisfies which protocol fn if names diverge.

## Option C: Hybrid (convention with override)

Convention by default, explicit override when names diverge.

```scheme
(satisfies sma-state indicator)    ;; convention: sma-step, sma-ready?, sma-reset

(satisfies special-indicator indicator
  :step    my-custom-step          ;; override: name doesn't follow convention
  :ready?  always-ready)           ;; another override
```

## The Rust mapping question

In Rust, `impl Trait for Struct` bundles all trait methods together.
The compiler requires all methods to be provided. The wat `satisfies`
should produce one `impl` block per (struct, protocol) pair.

Option A maps directly: each `:fn impl-fn` becomes a method delegation.
Option B requires the compiler to resolve conventions.
Option C does both.

## Questions for designers

1. Explicit (A), convention (B), or hybrid (C)?

2. Should `satisfies` be exhaustive? If the protocol declares 3 functions
   and `satisfies` maps only 2, is that an error or partial satisfaction?

3. Does the naming convention (struct-prefix + protocol-fn) hold for
   the enterprise's actual patterns? Check: `wilder-step`, `sma-step`,
   `rsi-step`, `atr-step` all follow `{name}-step`. But `new-sma`,
   `new-wilder` follow `new-{name}`, not `{name}-new`.
