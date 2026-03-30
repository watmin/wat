;; ── wat core — six primitives ───────────────────────────────────────
;;
;; Everything else composes from these. Nothing here is derivable
;; from the others. This is the irreducible kernel of the language.

;; Name a concept → deterministic bipolar vector.
;; Same seed + same name = same vector everywhere.
(atom name) → Vector

;; Compose two concepts into a relationship.
;; Self-inverse: (bind (bind A B) A) = B
(bind role filler) → Vector

;; Superimpose multiple relationships into one thought.
;; Associative, commutative, identity = zero vector.
(bundle fact1 fact2 ...) → Vector

;; Measure similarity between two thoughts.
;; The only measurement. One number.
(cosine thought direction) → Float  ; [-1.0, +1.0]

;; Accumulate labeled observations, produce predictions.
;; The state monad of the algebra.
(journal name dims recalib-interval) → Journal

;; Measure journal quality at each conviction level.
;; accuracy = 0.50 + a × exp(b × conviction)
(curve journal resolved) → (a, b)
