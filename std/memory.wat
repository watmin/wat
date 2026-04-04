;; ── std/memory — learning beyond the journal ────────────────────────
;;
;; The journal (core) is Template 1: prediction via discriminant.
;; These are Template 2: reaction via learned manifold.

;; Online subspace — learns what "normal" looks like from a stream.
;; CCIPCA: incremental PCA without storing the full dataset.
(online-subspace dims n-components) → Subspace

;; Feed an observation to the subspace.
(update subspace vector)

;; How many observations has the subspace seen?
(sample-count subspace) → Integer

;; Project vector onto the learned manifold (reconstruction).
;; Returns D-dimensional vector: the part the subspace CAN explain.
(project subspace vector) → Vector

;; The part the subspace CANNOT explain: vector minus reconstruction.
;; Returns D-dimensional vector (same dimension as input).
(anomalous-component subspace vector) → Vector

;; How far is this observation from the learned manifold? (scalar)
(residual subspace vector) → Float

;; Self-calibrating anomaly threshold.
(threshold subspace) → Float
