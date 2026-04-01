# Proposal 013: Boolean Literals and Nil

## Scope: structural

## Problem

The wat language has comparisons that produce booleans and control flow that
consumes them, but never names them. The language also lacks a way to express
"no value" -- the absence of a result.

Currently in the enterprise wat files:
- `curve-valid false` uses Scheme's `#f` (ugly, borrowed)
- `(when condition body)` returns body or implicitly nothing (unnamed)
- `(if x value ???)` has no clean way to say "no result" in the else branch
- `nothing` was used as a convention but is actually `(atom "nothing")` -- a vector, not absence

## Proposal

Add three literals to the host language:

```scheme
true    ; boolean affirmation
false   ; boolean negation
nil     ; the absence of value
```

### The distinction

`false` means "the answer is no."
`nil` means "there is no answer."

```scheme
;; An observer that hasn't proven its curve:
(observer :curve-valid false)    ; not yet proven -- answer is "no"

;; A position tick with no exit signal:
(define (tick pos price)
  (if (<= price (:trailing-stop pos)) :stop-loss
      nil))                           ; nothing happened -- no answer

;; A function that might not find a result:
(define (kelly-frac conviction resolved)
  (when (>= (len resolved) 500)       ; when returns body or nil
    ...))
```

### `when` returns nil

`(when condition body)` returns `body` when condition is truthy, `nil` when falsy.
`(when-let ((x expr)) body)` returns `body` when `x` is non-nil, `nil` when expr is nil.

This is already the implicit behavior. The proposal makes it explicit.

### Where they live

Host language, alongside the logical operators:

```
- **Logical:** `and`, `or`, `not`
- **Literals:** `true`, `false`, `nil`
```

## Tension: truthiness model

Clojure unifies nil and false as falsy. Everything else is truthy.
This is elegant in a dynamic language.

But wat compiles to Rust. Rust does not do truthiness:
- `if bool_val { ... }` -- only `bool` accepted
- `if let Some(x) = option { ... }` -- pattern match for Option
- `if 0 { ... }` -- compile error
- `if None { ... }` -- compile error

Two possible models:

**Model A -- Clojure truthiness (dynamic):**
nil and false are both falsy in `if`/`when`. The wat-to-Rust compiler
inserts `.is_some()` checks where needed. Elegant in wat, work for compiler.

**Model B -- Rust separation (static):**
`true`/`false` are bool. `nil` is Option::None. They never mix.
`if` takes bool. `when-let` handles nil. No implicit truthiness.
Honest to the compilation target.

## Precedent

- Clojure: Model A. nil + false both falsy. Hickey's choice for a dynamic language.
- Rust: Model B. bool and Option are separate types. No implicit conversion.
- Wat sits between: Lisp syntax, Rust compilation target.

## What this replaces

- `#f` becomes `false` (boolean) or `nil` (absence)
- `#t` becomes `true`
- `nothing` (bare atom) becomes `nil`

## What this does NOT do

- Does not add Option/Maybe types. `nil` is the value. `when-let` is the pattern.
- Does not change how `and`/`or` work. `(and x y)` still short-circuits.

## Question for designers

Which model? A or B? The literals (`true`, `false`, `nil`) are the same
either way. The question is whether they blend in conditionals.
