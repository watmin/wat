# The Wat Language

Wat is an s-expression language for algebraic cognition.

## Grammar

```ebnf
program    = form*
form       = atom | number | string | list | comment
atom       = letter (letter | digit | '-' | '?' | '!' | '>')*
number     = digit+ ('.' digit+)?
string     = '"' char* '"'
list       = '(' form* ')'
comment    = ';' char* newline
```

## Core Forms (corelib)

Two algebras. Everything else composes from these.

```scheme
;; Naming
(atom "name")                    → Vector

;; Composition
(bind role filler)               → Vector    ; two things become one relationship
(bundle fact1 fact2 ...)         → Vector    ; many facts become one thought

;; Measurement
(cosine thought discriminant)    → Float     ; [-1.0, +1.0]

;; Learning — journal coalgebra (opaque state, N-ary labels)
(journal name dims refit-interval) → Journal
(register journal name)          → Label      ; symbol handle — value-typed, O(1) equality
(observe journal thought label weight) → ()   ; label is a Label symbol
(predict journal thought)        → Prediction ; { scores, direction, conviction, raw_cos }
(decay journal rate)             → ()

;; Evaluation — the journal evaluates itself
(resolve journal conviction correct) → ()    ; accumulate a resolved prediction
(curve journal)                  → (a, b)    ; accuracy = (1/N) + a × exp(b × conviction)
```

## Standard Library (stdlib)

Derived forms built from the corelib.

```scheme
;; Scalar encoding
(encode-linear value scale)      → Vector    ; [0, scale] maps to orthogonal
(encode-log value)               → Vector    ; equal ratios = equal similarity
(encode-circular value period)   → Vector    ; endpoint wraps to start

;; Vector operations
(difference before after)        → Vector    ; structural change
(permute vector shift)           → Vector    ; element rotation
(negate superposition component) → Vector    ; remove component
(amplify superposition component strength) → Vector
(prototype vectors threshold)    → Vector    ; consensus extraction
(cleanup noisy codebook)         → Vector    ; snap to nearest
(attend query memory strength mode) → Vector ; soft attention
(coherence vectors)              → Float     ; mean pairwise similarity

;; Memory
(online-subspace dims k)         → Subspace
(update subspace vector)         → ()
(residual subspace vector)       → Float     ; distance from learned manifold
(threshold subspace)             → Float     ; self-calibrating boundary

;; Gate (derived pattern)
(gate journal thought proven?)   → Vector    ; bundle(prediction, credibility annotation)
;; The gate annotates — it does not suppress. The caller determines proof.
```

## Control Forms

```scheme
;; Binding
(let ((name value) ...) body)
(let* ((name value) ...) body)   ; sequential binding
(define (name args ...) body)    ; function definition

;; Conditional
(if test then else)
(when test body)
(match value (pattern body) ...)

;; Iteration
(for-each fn list)
(map fn list)
(filter fn list)
(filter-map fn list)
(fold step-fn initial-state items)   ; (state, element) → state
```

## Type Annotations (optional)

```scheme
;; Types are documentation, not enforcement.
;; The algebra doesn't type-check — the curve validates.
(define (weighted-thought [base : Vector]
                          [strength : Float]
                          [dims : Int])
  : Vector
  ...)
```

## Module System

```scheme
(require primitives)             ; corelib
(require common)                 ; stdlib atoms
(require mod/oscillators)        ; domain vocabulary
```

## What Wat Is Not

- Not a general-purpose language. It expresses algebraic cognition.
- Not Turing complete. It doesn't need to be. The algebra is sufficient.
- Not interpreted at runtime. Wat is compiled to Rust. The Rust runs.
- Not a replacement for Lisp. It IS Lisp, restricted to two algebras.

## What Wat Is

- A specification language for Holon programs.
- A shared language between human intuition and machine implementation.
- Parseable, validatable, structurally analyzable.
- The intermediate representation between thought and execution.
- Lisp with a purpose: algebraic cognition from named thoughts.

## Example

```scheme
;; A thought: "RSI is diverging from price during a regime shift"
(bundle
  (bind (atom "diverging") (bind (atom "close") (atom "rsi")))
  (bind (atom "at") (bind (atom "dfa-alpha") (atom "anti-persistent"))))

;; A journal learns which thoughts predict
(define jrnl (journal "example" 10000 500))
(register jrnl "Buy")
(register jrnl "Sell")
(observe jrnl thought label 1.0)
(predict jrnl thought)              ; → direction + conviction
(curve jrnl)                        ; → (a, b) — the proof
```

The full enterprise example is in `examples/enterprise.wat`.
