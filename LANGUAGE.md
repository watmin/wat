# The Wat Language

Wat is an s-expression language for algebraic cognition.

## Grammar

```ebnf
program    = form*
form       = atom | number | string | list | typed-param | comment
atom       = letter (letter | digit | '-' | '?' | '!' | '>')*
number     = digit+ ('.' digit+)?
string     = '"' char* '"'
list       = '(' form* ')'
typed-param = '[' atom ':' atom ']'
comment    = ';' char* newline
```

## Type Annotations (optional)

Sort annotations on parameters and return types. Parseable but not enforced.
Present when they clarify. Absent when obvious. The annotations are metadata
on a free algebra — they name which carrier set a variable lives in.

```scheme
;; Typed parameter: [name : Type]
(define (observe-scalar [acc : ScalarAccumulator] [value : f64])
  ...)

;; Return type: `: Type` after parameter list
(define (new-window-sampler [seed : usize] [min : usize] [max : usize])
  : WindowSampler
  ...)

;; Untyped is also valid — both accepted
(define (tick bank raw-candle) ...)
```

Tooling may extract annotations when present. The language never demands them.

## Host Language

Wat is Lisp. It inherits standard forms from the host:

- **Arithmetic:** `+`, `-`, `*`, `/`, `abs`, `sqrt`, `mod`, `max`, `min`, `round`, `clamp`, `exp`, `ln`, `signum`, `f64-infinity`, `f64-neg-infinity`
- **Comparison:** `=`, `!=`, `>`, `<`, `>=`, `<=`
- **Logical:** `and`, `or`, `not`, `true`, `false`
- **Sequencing:** `begin`
- **Iteration:** `for-each`, `map`, `filter`, `filter-map`, `fold`, `fold-left`, `count`, `pmap`, `pfor-each`
- **Collections:** `list`, `cons`, `len`, `length`, `nth`, `first`, `second`, `rest`, `last`, `last-n`, `take`, `append`, `take-last`, `empty?`, `reverse`, `sort`, `sort-by`, `flatten`, `range`, `unzip`, `zeros` *(nullary: zero vector at dims; `(zeros n)`: zero-filled array of size n)*, `member?`, `some?`, `quantile`, `apply` *(apply function to list as arguments: `(apply bundle vectors)`)*
- **Maps:** `map-of` *(constructor: `(map-of k1 v1 k2 v2)` — flat key-value pairs, a value not an entity)*, `get`, `assoc` *(variadic: `(assoc m k1 v1 k2 v2)`, sequential — later entries see earlier changes)*, `keys`, `dissoc`
- **Queues:** `deque`, `push-back`, `pop-front`
- **Strings:** `format`, `substring`
- **Control:** `let` *(supports destructuring: `(let (((a b) (f x))) body)` — the return is a list, destructuring is projection)*, `let*`, `define`, `if`, `when`, `when-let`, `cond` *(`else` as catch-all clause)*, `match`, `lambda`
- **Quote:** `'(...)` or `(quote ...)` — data, not execution. The s-expression IS the tree.
  The vocabulary produces quoted expressions. The encoder evaluates them.
  Recursive structure is natural — `'(Bind (Atom "rsi") (Linear "close" 0.73 1.0))`
  is a nested list. No special type needed. The parentheses ARE the tree.
- **Optionals:** `(Some value)`, `None` *(Rust: Option<T>. Match with `(Some x)` and `None`.)*
- **Mutation:** `set!` *(single: `(set! place value)`, indexed: `(set! collection index value)`)*, `push!`, `pop!`, `inc!` *(Rust compilation target — these map to &mut self)*
- **Pipes:** `make-pipe` *(constructor: `(make-pipe :capacity N :carries Type)` → `(tx, rx)` pair. Destructure at creation.)*, `send` *(blocking write: `(send tx value)`)*, `recv` *(blocking read: `(recv rx)` → value)*, `try-recv` *(non-blocking: `(try-recv rx)` → `(Some value)` or `None`)*, `select` *(multiplex N rx ends: `(select pipes)` → `(Some (idx value))` or `:closed`. Parks when idle — zero CPU.)*
- **Fan-out:** `make-topic` *(wires 1→N: `(make-topic (list tx1 tx2 tx3))` → topic. A topic is a write-only value. `(send topic value)` clones to all outputs synchronously — no thread, no queue, the caller's send IS the fan-out. The subscribers already have their rx ends from `make-pipe`.)*
- **Threads:** `spawn` *(run a function on a thread: `(spawn (lambda () body))` → Handle. A process is a function. The caller spawns it.)*, `join` *(block until all handles in a list complete: `(join handles)` → list of return values. Always takes a list. Always returns a list.)*

`pmap` and `pfor-each` are parallel variants of `map` and `for-each`.
Semantically identical — same results, same order. The parallelism is
a permission, not a directive. The runtime may evaluate sequentially.

- `pmap`: the mapped function must be pure (no `set!`, `push!`, `inc!`).
  Ward-enforced at compile time. Result order matches input order.
- `pfor-each`: each element's mutations must be disjoint (each invocation
  mutates through its own root object). Ward checks what it can;
  programmer asserts the rest.
- No `pfold`: a fold is inherently sequential. Parallel reduce uses
  `(fold f init (pmap g xs))` — the MapReduce pattern.

## Pipes

Pipes are CSP (communicating sequential processes). The algebra
lives in **Vect**. The pipes live in **Proc**. Orthogonal.

A pipe is a value. `make-pipe` creates one. Returns a `(tx, rx)` pair.
Destructure at creation. Pass the ends into functions. A process is
just a function that loops over pipe ends. `spawn` puts it on a thread.

```scheme
;; Create a pipe. Capacity is a number (items in flight) or :unbounded.
;; :carries declares the type that crosses the boundary.
(let (((tx rx) (make-pipe :capacity 1 :carries ObsOutput)))
  ;; tx — the sender end. Blocks when capacity is full.
  ;; rx — the receiver end. Blocks when empty.
  (spawn (lambda () (producer tx)))
  (consumer rx))

;; Unbounded: sender never blocks. Buffer grows.
(let (((learn-tx learn-rx) (make-pipe :capacity :unbounded :carries LearnSignal)))
  ...)
```

`select` multiplexes N pipe ends. Returns `(Some (idx value))` or
`:closed`. Parks when idle — zero CPU. The function knows its layout.
The index is the dispatch.

```scheme
;; A service is just a function that selects over pipes.
;; Layout: pipes interleave [request, learn] pairs per client.
(define (encoder-service-loop pipes replies cache)
  (let ((n (/ (len pipes) 2)))
    (loop
      (match (select pipes)
        ((Some (idx value))
          (let ((client    (/ idx 2))
                (direction (mod idx 2)))
            (if (= direction 0)          ; request — look up and reply
              (send (nth replies client) (get cache value))
              (let (((ast vec) value))    ; learn — store new encoding
                (set! cache ast vec)))))
        (:closed (break))))))

;; The binary spawns it.
(spawn (lambda () (encoder-service-loop pipes replies cache)))
```

No `defpipe`. No `defprocess`. No `defservice`. Pipes are values.
Processes are functions. The forms are `make-pipe`, `send`, `recv`,
`try-recv`, `select`, `spawn`. Six verbs. Everything else is
regular functions.

These are the substrate any Lisp provides, plus the pipe forms
from Proposals 002 and 003. Wat's contribution is the algebras,
structural forms, and stdlib below.

## File layout

```
core/
  primitives.wat      — the four algebra generators + reckoner coalgebra
  structural.wat      — struct, enum, newtype, defprotocol
std/
  vectors.wat         — derived vector operations (amplify, zeros, blend, etc.)
  scalars.wat         — scalar encoding (encode-log, encode-linear, encode-circular)
  memory.wat          — OnlineSubspace (CCIPCA anomaly detection)
  statistics.wat      — statistical functions
  fields.wat          — field access utilities
```

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

;; Learning — reckoner coalgebra (opaque state, N-ary labels)
;; Constructor: Reckoner::new(name, dims, recalib_interval, config) in holon-rs.
;; config is ReckConfig: Discrete(labels) or Continuous(default_value).
;; dims and recalib-interval are separate parameters, not inside config.
(reckoner name dims recalib-interval config) → Reckoner
(observe reckoner thought observation weight) → () ; observation is label (discrete) or scalar (continuous)
(predict reckoner thought)       → Prediction ; Discrete: scores + conviction. Continuous: value + experience.
(decay reckoner rate)            → ()
(experience reckoner)            → f64       ; how much has this reckoner learned? 0.0 = ignorant.

;; Introspection — read the reckoner's learned state
(recalib-count reckoner)         → Integer   ; how many prototype rebuilds
(discriminant reckoner label)    → Vector | None ; learned separation between labels
(labels reckoner)                → [Label]   ; registered labels in registration order
(label-count reckoner label)     → Integer   ; observations accumulated for this label

;; Curve — the reckoner evaluates itself. Not a separate object.
;; The reckoner carries its own curve internally. These are methods on the reckoner.
;; holon-rs: resolve(), accuracy_at(), curve_valid() on Reckoner.
(resolve reckoner conviction correct?) → ()  ; feed a resolved prediction to the internal curve
(edge-at reckoner conviction)    → f64       ; query: how accurate at this conviction level?
(proven? reckoner min-samples)   → bool      ; enough data to trust the curve?

;; Structural — products and coproducts for program state
(struct name field1 field2 ...)  ; declare a named product type
;; Optional values use (Some value) and None — Rust: Option<T>.
;; No naming convention needed — the type carries the optionality.
(:field record)                  → value     ; keyword as function — project a field
(update record :field1 value1 ...) → record  ; functional update — variadic, parallel semantics
(enum name variant1 variant2 ...)            ; declare a sum type — exactly one alternative
;; match on enum must be exhaustive — every variant handled
(newtype name inner-type)                    ; declare a distinct type wrapping another
;; A newtype is about MEANING, not structure. TradeId is not a usize —
;; it is a TradeId that happens to be represented as a usize. The names
;; are load-bearing. Maps to Rust's tuple struct: struct TradeId(usize).

;; Struct constructors follow the make-<name> convention.
;; (make-broker ...) constructs a Broker.

;; Protocols — type classes for shared behavior
(defprotocol name                            ; declare a set of function signatures
  (fn-name [params] "docstring"))            ; check-only — no dispatch
(satisfies struct-name protocol-name         ; declare that a struct satisfies a protocol
  :fn1 impl1 :fn2 impl2 ...)               ; maps ALL protocol fns — exhaustive, explicit
;; The forge checks: does impl-fn exist? Correct arity?
;; Rust mapping: defprotocol → trait, satisfies → impl Trait for Struct
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
(anomalous-component subspace vector) → Vector ; what the subspace CANNOT explain — the residual vector
(sample-count subspace)          → Integer   ; how many observations has this subspace seen?
(threshold subspace)             → Float     ; self-calibrating boundary

;; Derived fields — RETIRED (proposal 014). Use defprotocol + satisfies.
;; (field struct-name field-name computation) — removed.
;; Protocols subsume derived fields. Behavior is separate from data.

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

;; A reckoner learns which thoughts predict
(let ((name "example")
      (dims 10000)
      (recalib-interval 500)
      (labels '("Buy" "Sell")))
  (define rk (reckoner name dims recalib-interval (Discrete labels)))
  (let ((buy  "Buy")
        (sell "Sell"))
    (observe rk thought buy 1.0)       ; label is a string, weight is 1.0
    (predict rk thought)               ; → Prediction (scores + conviction)
    (let ((conviction 0.25)
          (correct true)
          (min-samples 100))
      (resolve rk conviction correct)  ; feed the internal curve
      (edge-at rk conviction)          ; → f64 — how accurate at this conviction?
      (proven? rk min-samples))))
```

The full enterprise example is in `examples/enterprise.wat`.
