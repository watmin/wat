# Proposal 014: Protocols

## Scope: structural

## Problem

The trading enterprise's indicator library reveals a recurring pattern:
every indicator is a state struct + a pure step function + a constructor.
The convention is clear but unenforced:

```scheme
(struct sma-state buffer period)
(define (new-sma period) ...)
(define (sma-step state value) ...)   ;; (state, input) → (state, output)

(struct wilder-state count accum prev period)
(define (new-wilder period) ...)
(define (wilder-step state value) ...)
```

Nothing in the language says "these share a shape." A new indicator that
omits the step function compiles fine. The convention is discovered by
reading existing code, not enforced by the language.

This is not unique to indicators. The enterprise has other protocol-shaped
patterns:
- Vocab modules: `(eval-X candles) → (list Fact)` — same shape, different X
- Risk branches: `(encode-X portfolio) → Vector` + `(update subspace vector)`
- Journal consumers: `(observe journal thought label weight)` — every observer
  calls the same interface

The language has struct (product types) and enum (sum types). It lacks a
way to say "these types share behavior."

## Prior art: Clojure

Clojure solves this with `defprotocol` + `reify`/`defrecord`:

```clojure
(defprotocol Indicator
  (step [this input] "Advance state by one input. Returns [new-state output]."))

(defrecord SmaState [buffer period]
  Indicator
  (step [this value]
    (let [buf (conj buffer value)
          buf (if (> (count buf) period) (subvec buf 1) buf)]
      [(->SmaState buf period)
       (/ (reduce + buf) (count buf))])))
```

The protocol declares the interface. The record implements it. The compiler
checks that every record claiming to implement the protocol provides all
required functions.

## Proposal

Add two forms to the structural layer:

### defprotocol

Declares a set of function signatures that types can implement.

```scheme
(defprotocol indicator
  (step [state input] "Advance by one input. Returns (new-state, output)."))

(defprotocol vocab-module
  (eval [module candles] "Perceive candles. Returns (list Fact)."))
```

A protocol is:
- A name
- One or more function signatures (name, parameter list, optional docstring)
- No implementation — the protocol says WHAT, not HOW

### implement

Declares that a struct satisfies a protocol by providing implementations.

```scheme
(struct sma-state buffer period)

(implement sma-state indicator
  (define (step state value)
    (let ((buf (push-back (:buffer state) value)))
      (let ((buf (if (> (len buf) (:period state)) (pop-front buf) buf)))
        (list (update state :buffer buf)
              (/ (fold + 0.0 buf) (len buf)))))))
```

Or inline with the struct declaration:

```scheme
(struct sma-state buffer period
  :implements indicator
  (define (step state value) ...))
```

### Dispatch

Protocol functions dispatch on the first argument's type:

```scheme
(step my-sma-state 42.0)     ;; dispatches to sma-state's implementation
(step my-wilder-state 42.0)  ;; dispatches to wilder-state's implementation
```

The compiler generates a vtable or match dispatch. The wat author
writes `(step state value)` and the right implementation runs.

### Alternative: no dispatch, just checking

A simpler version: the protocol is only a compile-time check. No dispatch.
The user calls `sma-step` or `wilder-step` directly. The protocol just
verifies that the required functions exist with the right shape.

```scheme
(defprotocol indicator
  (step [state input] -> (state output)))

(struct sma-state buffer period
  :satisfies indicator
  :step sma-step)          ;; names the function that satisfies `step`
```

This is weaker but avoids the dispatch machinery. The protocol is
documentation-with-teeth, not a runtime mechanism.

## What about reify?

Clojure's `reify` creates an anonymous type implementing a protocol.
Useful when you need a one-off implementation without declaring a struct.

For wat, `reify` may be premature. The enterprise's patterns all use
named structs. If a use case for anonymous protocol implementations
appears, `reify` can be proposed separately. Start with named structs.

## The relationship to (field ...)

`(field struct-name field-name computation)` was proposal 011. It tried
to express "this struct has a derived property." With indicators becoming
fold steps, `field` has no remaining consumer.

Protocols subsume what `field` was trying to do. Instead of "this struct
has this derived field," you say "this type satisfies this interface."
The protocol is the right abstraction. If accepted, `field` can be
retired from the language.

## What this does NOT do

- Does not add inheritance. Protocols are interfaces, not base classes.
- Does not add generics or type parameters. The step function's input
  type varies per indicator — the protocol checks shape, not types.
- Does not change the algebra. Protocols are structural, orthogonal to
  bind/bundle/cosine.
- Does not require runtime dispatch (the check-only variant avoids it).

## Questions for designers

1. Should protocols dispatch (call `step` on any indicator) or just check
   (verify the function exists)? Dispatch is powerful but adds machinery.
   Checking is simple but forces the caller to know the concrete type.

2. Should implementation be inline with the struct or separate? Inline
   is concise. Separate allows implementing protocols for existing structs
   without modifying them.

3. Should protocols specify return types? `(step [state input] -> (state output))`
   adds type checking. But wat's type annotations are optional.

4. Does this replace `(field ...)`? If so, should proposal 011 be retired?
