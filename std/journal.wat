;; ── std/journal — operations on the journal primitive ───────────────
;;
;; The journal (core) creates the stateful container.
;; These operations interact with it.
;;
;; Tension: Hickey says these are derivable (observe ≈ bundle into
;; accumulator, predict ≈ cosine against discriminant, decay ≈ scalar
;; multiply). Beckman says they're co-generators of the journal
;; coalgebra — not derivable because the journal is opaque state.
;;
;; Interim placement: stdlib per Proposal 003 resolution.
;; May move to core if the coalgebra argument prevails.
;;
;; See: docs/proposals/003-language-layers/

;; Accumulate a labeled observation into the journal.
;; label = Buy | Sell. weight scales the contribution.
(observe journal thought label weight)

;; Ask the journal what it thinks about a thought.
;; Returns direction (Buy/Sell/None) and conviction (|cosine|).
(predict journal thought) → Prediction  ; { direction, conviction, raw-cos }

;; Decay the journal's accumulators by a factor.
;; Older observations fade. Recent ones dominate.
(decay journal rate)
