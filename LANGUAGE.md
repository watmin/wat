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

## Host Language

Wat is Lisp. It inherits standard forms from the host:

- **Arithmetic:** `+`, `-`, `*`, `/`, `abs`, `sqrt`, `mod`, `max`, `min`, `round`, `clamp`, `exp`, `ln`, `signum`
- **Comparison:** `=`, `!=`, `>`, `<`, `>=`, `<=`
- **Logical:** `and`, `or`, `not`
- **Sequencing:** `begin`
- **Iteration:** `for-each`, `map`, `filter`, `filter-map`, `fold`, `fold-left`, `count`
- **Collections:** `list`, `len`, `length`, `nth`, `first`, `second`, `rest`, `last`, `last-n`, `take`, `append`, `take-last`, `empty?`, `reverse`, `sort`, `sort-by`, `flatten`, `range`, `unzip`, `zeros`, `member?`, `some?`, `quantile`
- **Maps:** `get`, `assoc` *(variadic: `(assoc m k1 v1 k2 v2)`, sequential — later entries see earlier changes)*, `keys`, `dissoc`
- **Queues:** `deque`, `push-back`, `pop-front`
- **Strings:** `format`, `substring`
- **Control:** `let`, `let*`, `define`, `if`, `when`, `when-let`, `cond`, `match`, `lambda`
- **Mutation:** `set!`, `push!`, `pop!`, `inc!` *(Rust compilation target — these map to &mut self)*

These are the substrate any Lisp provides. Wat's contribution
is the algebras, structural forms, and stdlib below.

## Core Forms (corelib)

Two algebras and one structural form. The algebras transform values.
The structural form carries them.

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
(register journal name)          → Label
(observe journal thought label weight) → ()   ; label is a Label symbol
(predict journal thought)        → Prediction ; { scores, direction, conviction, raw-cosine }
(decay journal rate)             → ()

;; Evaluation — the journal evaluates itself
(resolve journal conviction correct) → ()    ; accumulate a resolved prediction
(curve journal)                  → (amplitude, exponent) ; accuracy = (1/N) + a × exp(b × conviction)

;; Structural — products and coproducts for program state
(struct name field1 field2 ...)  ; declare a named product type
(:field record)                  → value     ; keyword as function — project a field
(update record :field1 value1 ...) → record  ; functional update — variadic, parallel semantics
(enum name variant1 variant2 ...)            ; declare a sum type — exactly one alternative
;; match on enum must be exhaustive — every variant handled
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

;; Derived fields — build-time declarations on product types
(field struct-name field-name computation)
;; Declares a computed value. Dependency order, no forward refs.

;; Statistics — pre-algebra numeric helpers
(mean xs)                            → Float
(variance xs)                        → Float
(stddev xs)                          → Float
(skewness xs)                        → Float
```

## Type Annotations (optional)

```scheme
;; Types are documentation, not enforcement.
;; The algebra doesn't type-check — the curve validates.
(define (weighted-thought [base : Vector]
                          [strength : Float])
  : Vector
  (bind base (encode-linear strength 1.0)))
```

## Module System

```scheme
(require primitives)             ; corelib
(require common)                 ; stdlib atoms
(require mod/my-vocabulary)      ; domain vocabulary
```

## What Wat Is Not

- Not a general-purpose language. It expresses algebraic cognition.
- Not Turing complete. It doesn't need to be. The algebra is sufficient.
- Not interpreted at runtime. Wat specifies Rust implementations. The Rust runs.
- Not a replacement for Lisp. It IS Lisp, shaped for algebraic cognition and the programs that use it.

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
(let ((buy  (register jrnl "Buy"))     ; string → Label symbol
      (sell (register jrnl "Sell")))
  (observe jrnl thought buy 1.0)       ; label is a symbol, not a string
  (predict jrnl thought)               ; → direction + conviction
  (curve jrnl))                        ; → (amplitude, exponent) — the proof
```

The full enterprise example is in `examples/enterprise.wat`.
