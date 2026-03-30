;; ── wat core — five generators, nine forms ──────────────────────────
;;
;; Two algebraic structures. Nothing here is derivable from the others.
;;
;; If a type is opaque, its interface operations are core.

;; ── Vector Algebra (4 generators) ───────────────────────────────────
;;
;; A commutative monoid under bundle, with bind as the group action
;; and cosine as the measurement homomorphism.

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

;; ── Journal Coalgebra (1 generator, 5 forms) ────────────────────────
;;
;; Opaque state. The co-generators produce all observable behavior.
;; Removing any one makes the external characterization incomplete.
;; Uses the algebra internally (observe bundles, predict cosines)
;; but the state threading is its own structure.

;; Create a journal — the learning primitive.
;; Contains: buy accumulator, sell accumulator, discriminant.
(journal name dims recalib-interval) → Journal

;; Accumulate a labeled observation.
;; The state transition function of the coalgebra.
(observe journal thought label weight)  ; label = Buy | Sell

;; Ask what the journal thinks about a thought.
;; The observation function of the coalgebra.
(predict journal thought) → Prediction  ; { direction, conviction, raw-cos }

;; Decay the accumulators. Older observations fade.
;; The aging function of the coalgebra.
(decay journal rate)

;; Measure journal quality at each conviction level.
;; The evaluation function of the coalgebra.
;; accuracy = 0.50 + a × exp(b × conviction)
(curve journal resolved) → (a, b)
