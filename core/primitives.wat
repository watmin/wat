;; ── wat core ────────────────────────────────────────────────────────
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

;; ── Journal Coalgebra ───────────────────────────────────────────────
;;
;; Opaque state. The co-generators produce all observable behavior.
;; Removing any one makes the external characterization incomplete.
;; Uses the algebra internally (observe bundles, predict cosines)
;; but the state threading is its own structure.
;;
;; Labels are symbols — created from strings once, used as cheap
;; integer handles forever. Like Ruby's :buy or Clojure's :buy.
;; N-ary: any number of labels, any domain.

;; Create a journal — the learning primitive.
;; Labels are registered after construction via (register journal name).
(journal name dims refit-interval) → Journal

;; Register a label and get its symbol handle.
;; Idempotent: same name → same handle. Runtime-derivable.
(register journal name) → Label

;; Accumulate a labeled observation.
;; The state transition function of the coalgebra.
;; label is a Label symbol, not a string.
;; weight scales the observation's influence on the accumulator.
(observe journal thought label weight)

;; Ask what the journal thinks about a thought.
;; Returns scores for ALL labels. The consumer decides top-1/top-k/full.
;; The observation function of the coalgebra.
(predict journal thought) → Prediction  ; { scores, direction, conviction, raw-cosine }

;; Decay the accumulators. Older observations fade.
;; The aging function of the coalgebra.
(decay journal rate)

;; Record a resolved prediction for curve fitting.
;; "I predicted with this conviction, and I was correct/wrong."
(resolve journal conviction correct)

;; Introspection — read the journal's learned state.

;; How many times the journal has rebuilt its prototypes.
;; Monotonically increasing integer. Used to detect recalibration events.
(recalib-count journal) → Integer

;; The learned separation vector between label prototypes.
;; discriminant(label) = prototype(label) - prototype(other).
;; None if < 2 labels registered or journal not yet calibrated.
;; The discriminant IS the journal's learned knowledge, externalized.
(discriminant journal label) → Vector | None

;; Fit the conviction-accuracy curve from resolved predictions.
;; The evaluation function of the coalgebra.
;; accuracy = (1/N) + a × exp(b × conviction),  N = number of labels.
;; At zero conviction, accuracy = 1/N (random chance among N labels).
;; The curve IS the proof. Monotonically increasing = real signal.
(curve journal) → (amplitude, exponent)
