;; ── std/patterns — derived patterns from core ───────────────────────
;;
;; Patterns that compose the six primitives into higher-level concepts.
;; Not new algebra — named compositions.

;; Gate: controls information flow based on curve validation.
;; Not a primitive — a conditional from the curve.
(define (gate journal curve threshold)
  (if (> (curve journal) threshold)
      (predict journal)
      silence))
