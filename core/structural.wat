;; ── wat structural forms ─────────────────────────────────────────────
;;
;; The ambient category's product construction.
;; Programs need structure beyond the two algebras.
;; Records carry values through the fold. The algebras transform them.
;;
;; These forms are orthogonal to the vector algebra and journal coalgebra.
;; A record cannot be bound, bundled, or cosined. It holds things that can.

;; Declare a product type — named fields that travel together.
;; Untyped: the wat struct names the shape, the Rust struct names the types.
;; Opaque: no destructuring, no pattern matching on fields. Projections only.
(struct name field1 field2 ...)

;; Project a field — keyword as function.
;; (:experts state) reads as "experts of state."
;; One syntax for access, construction, and update.
(:field record) → value

;; Functional update — return a new record with one field changed.
;; No mutation. The old record is unchanged. The new one differs in one field.
(update record :field value) → record
