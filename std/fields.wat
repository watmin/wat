;; ── std/fields — derived values on product types ─────────────────────
;;
;; A field declares a computed value on a struct.
;; The struct owns the shape. The field declares the derivation.
;; Build-time declaration, not a runtime operation.
;; The wat says WHAT to compute. The Rust implements HOW.

(require core/structural)

;; Declare a derived field on a product type.
;; The struct must already be declared.
;; Lexical order IS the dependency order — no forward references.
;; Name resolution: sibling derived fields → stored struct fields → stdlib.
;; Missing reference = static error. Circular dependency = static error.
(field struct-name field-name computation)

;; Example:
;;   (struct raw-candle ts open high low close volume)
;;   (field raw-candle sma20    (sma close 20))
;;   (field raw-candle bb-upper (+ sma20 (* 2.0 (stddev close 20))))
;;   bb-upper references sma20 — declared above, so the dependency resolves.
