;; ── std/vectors — derived vector operations ─────────────────────────
;;
;; All derivable from the four algebra primitives (atom, bind, bundle, cosine).
;; Stdlib convenience, not core.

;; Shift vector elements — orthogonal encoding of ordered alternatives.
;; (permute A 0) = A.  (permute A 1) is quasi-orthogonal to A.
(permute vector shift) → Vector

;; Structural change between two states.
;; What's new in `after` that wasn't in `before`.
(difference before after) → Vector

;; Remove a component from a superposition.
(negate superposition component) → Vector

;; Boost component presence in a superposition.
(amplify superposition component strength) → Vector

;; Extract consensus from examples.
(prototype vectors threshold) → Vector

;; Snap noisy observation to nearest known pattern.
(cleanup noisy codebook) → Vector

;; Soft attention over memory.
(attend query memory strength mode) → Vector  ; mode: :hard | :soft

;; Mean pairwise similarity of a vector set.
(coherence vectors) → Float
