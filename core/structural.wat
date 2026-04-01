;; ── wat structural forms ─────────────────────────────────────────────
;;
;; The ambient category's three constructions:
;;   Product   (struct)       — named fields that travel together
;;   Coproduct (enum)         — exactly one of several alternatives
;;   Type class (defprotocol) — shared behavior across types
;;
;; Programs need structure beyond the two algebras.
;; Structs and enums carry values through the fold. The algebras transform them.
;; Protocols declare what types can do. The forge checks. The Rust enforces.
;;
;; These forms are orthogonal to the vector algebra and journal coalgebra.
;; A struct cannot be bound, bundled, or cosined. It holds things that can.
;; An enum variant is an identity, not a geometric object.
;; A protocol is a contract, not a computation.

;; ── Product (struct) ────────────────────────────────────────────────

;; Declare a product type — named fields that travel together.
;; Untyped: the wat struct names the shape, the Rust struct names the types.
;; Opaque: no destructuring, no pattern matching on fields. Projections only.
;;
;; A field name ending in ? is optional — it may be absent.
;; In Rust: Option<T>, initialized to None when not provided in constructor.
;; In wat: (when-let ((x (:field? record))) ...) to access.
(struct name field1 field2 ...)
;; (struct side-state latest? age staleness)  ; latest? is optional

;; Project a field — keyword as function.
;; (:experts state) reads as "experts of state."
;; One syntax for access, construction, and update.
(:field record) → value

;; Functional update — return a new record with fields changed.
;; Variadic: one or more :field value pairs. Parallel semantics —
;; all field expressions evaluate against the ORIGINAL record.
;; If a field depends on another field's new value, use let.
(update record :field1 value1 ...) → record

;; ── Coproduct (enum) ────────────────────────────────────────────────

;; Declare a sum type — exactly one of these alternatives.
;; Simple variants are keywords. Tagged variants carry data.
;; Match must be exhaustive — every variant handled.
;;
;; Simple:  (enum direction :long :short)
;; Tagged:  (enum event (candle asset candle) (deposit asset amount))
;; Mixed:   (enum phase :observe :tentative :confident)
(enum name variant1 variant2 ...)

;; Match dispatches on the active variant.
;; Exhaustive: missing an arm on a closed set is a spec violation.
;; Wildcard `_` is forbidden on closed enums — it defeats exhaustiveness.
;; When a variant is added, every match must be updated. That is the point.
;; The forge checks this. The Rust compiler enforces it.
;;
;; (match (:direction pos)
;;   :long  (handle-long)
;;   :short (handle-short))
;;
;; (match event
;;   (candle asset candle)   (process-candle asset candle)
;;   (deposit asset amount)  (deposit treasury asset amount))

;; ── Type class (defprotocol) ───────────────────────────────────────

;; Declare a set of function signatures that types can satisfy.
;; Check-only — no dispatch machinery. The forge checks existence and arity.
;; The Rust compiler enforces the trait implementation.
;;
;; defprotocol → Rust trait
;; satisfies   → Rust impl Trait for Struct
;;
;; Protocols never enter the algebra. They organize programs, not vectors.

(defprotocol name
  "Docstring — what this protocol means."
  (fn-name [params] "What this function does."))

;; (defprotocol indicator
;;   "A scalar stream processor. State in, state out."
;;   (step [state input] "Advance by one input. Returns (state, output)."))

;; Declare that a struct satisfies a protocol.
;; Separate from the struct — behavior is not data.
;; Maps each protocol function to a concrete implementation.

(satisfies struct-name protocol-name
  :fn-name impl-fn-name)

;; (satisfies sma-state indicator
;;   :step sma-step)
;;
;; The forge checks:
;;   - Does sma-step exist?
;;   - Does sma-step take sma-state as first argument?
;;   - Correct arity?
;; The Rust compiler enforces the full trait contract.
