;; ── std/memory — learning beyond the journal ────────────────────────
;;
;; The journal (core) is Template 1: prediction via discriminant.
;; These are Template 2: reaction via learned manifold.

;; Online subspace — learns what "normal" looks like from a stream.
;; CCIPCA: incremental PCA without storing the full dataset.
(online-subspace dims k) → Subspace

;; Feed an observation to the subspace.
(update subspace vector)

;; How far is this observation from the learned manifold?
(residual subspace vector) → Float

;; Self-calibrating anomaly threshold.
(threshold subspace) → Float
