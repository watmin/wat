;; ── wat structural forms ─────────────────────────────────────────────
;;
;; The ambient category's product and coproduct constructions.
;; Programs need structure beyond the two algebras.
;; Structs and enums carry values through the fold. The algebras transform them.
;;
;; These forms are orthogonal to the vector algebra and journal coalgebra.
;; A struct cannot be bound, bundled, or cosined. It holds things that can.
;; An enum variant is an identity, not a geometric object.

;; ── Product (struct) ────────────────────────────────────────────────

;; Declare a product type — named fields that travel together.
;; Untyped: the wat struct names the shape, the Rust struct names the types.
;; Opaque: no destructuring, no pattern matching on fields. Projections only.
(struct name field1 field2 ...)

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
