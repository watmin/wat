# Proposal 007: Struct Syntax

**Scope:** structural — the concrete syntax for aggregate types accepted in proposal 006.

**Precursor:** Proposal 006 established that wat needs named product types. Both designers approved conditionally. This proposal resolves the syntax.

## 1. The current state

Proposal 006 accepted `defrecord` as the form name, dot access `(. record field)` for projection, and `(update record :field value)` for functional update. But the name `defrecord` is Clojure heritage. Wat compiles to Rust. Rust calls these `struct`.

The datamancer asks: what syntax bridges Lisp and Rust? The form must be digestible as an s-expression AND recognizable to someone who reads the compiled Rust.

## 2. The constraint

Wat is a Lisp that compiles to Rust. The syntax should:
- Feel natural in s-expression form (parenthesized, prefix notation)
- Map transparently to Rust (the reader should see the Rust struct in the wat declaration)
- Not require new reader forms (no curly braces, no special tokens)
- Be consistent with wat's existing naming conventions (lowercase, hyphenated)

## 3. The candidates

### A. `defstruct` (Common Lisp heritage)

```scheme
(defstruct enterprise-state
  experts
  generalist
  manager
  risk
  treasury)

(defstruct trade-pnl
  gross-return
  net-return
  position-usd)
```

Pros: `def` prefix is Lisp convention for top-level definitions (`define`, `defrecord`). `struct` is Rust's word.
Cons: `defstruct` in Common Lisp has connotations (auto-generated accessors, `make-foo`, `foo-p`). Wat's version is simpler.

### B. `struct` (Rust's word, bare)

```scheme
(struct enterprise-state
  experts
  generalist
  manager
  risk
  treasury)
```

Pros: Shortest. Maps directly to Rust's `struct EnterpriseState { ... }`. No heritage baggage.
Cons: Breaks the Lisp `def*` convention for declarations. But wat already breaks Lisp conventions — it's not a general-purpose Lisp.

### C. `record` (ML/Haskell heritage)

```scheme
(record enterprise-state
  experts
  generalist
  manager
  risk
  treasury)
```

Pros: Domain-neutral. No language heritage bias.
Cons: Rust doesn't call them records. The compiled output says `struct`, not `record`.

## 4. Access syntax

Proposal 006 resolved on dot: `(. state field)`. But there are sub-choices:

### A. Bare dot

```scheme
(. state experts)              ; project
(update state :experts value)  ; functional update
```

### B. Dot as method-call style

```scheme
(.experts state)               ; Clojure's Java interop style
```

### C. Keyword projection

```scheme
(:experts state)               ; Clojure's keyword-as-function
```

The resolution from 006 chose dot `(. state field)`. This proposal asks: is that the right choice given that Rust uses `state.experts`? The dot form `(. state experts)` is prefix notation for what Rust writes as infix. It's honest.

## 5. Construction syntax

```scheme
;; Named fields (explicit)
(enterprise-state
  :experts experts
  :generalist generalist
  :treasury treasury)

;; Positional (implicit, matches declaration order)
(enterprise-state experts generalist treasury)
```

Named construction is safer (immune to field reordering). Positional is terser. Rust uses named construction (`EnterpriseState { experts, generalist, treasury }`). Wat should match.

## 6. The heartbeat after

Whatever syntax we choose, the 16-parameter heartbeat becomes:

```scheme
(struct enterprise-state
  experts generalist manager risk treasury
  positions exit-expert pending band ledger
  last-exit-price last-exit-atr)

;; rune:gaze(length) — gone. The rune is no longer needed.
(define (heartbeat candle-idx candle vector-manager state)
  (let* ((expert-preds (map (lambda (e) (e candle))
                            (. state experts)))
         ...)
    (update state :last-exit-price new-price)))
```

Four parameters. The state is one thing. The runes dissolve.

## 7. Questions for designers

1. **`defstruct`, `struct`, or `record`?** Which name bridges Lisp and Rust with the least baggage?

2. **Typed fields or untyped?** Should the declaration carry type annotations?
   ```scheme
   ;; Untyped (wat convention — types are documentation)
   (struct trade-pnl gross-return net-return position-usd)
   
   ;; Typed (self-documenting)
   (struct trade-pnl
     [gross-return : Float]
     [net-return : Float]
     [position-usd : Float])
   ```

3. **Named or positional construction?** Rust uses named. Lisp tradition is positional. Wat compiles to Rust. Which serves the specification?

4. **Does `update` take a keyword or a bare symbol?** `(update state :field value)` vs `(update state field value)`. Keywords distinguish field names from values. Bare symbols are simpler.

5. **Should the form support nested access?** `(. (. state treasury) balance)` or `(.. state treasury balance)`? Or is nesting an anti-pattern that the flat projection handles?
