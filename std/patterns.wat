;; ── std/patterns — derived patterns from core ───────────────────────
;;
;; Patterns that compose the primitives into higher-level concepts.
;; Not new algebra — named compositions.

;; Gate: annotates a vector with credibility status.
;; The message always flows. The consumer decides what credibility means.
;; The filter is a thought, not a suppression.
;;
;; The gate does NOT predict or project. It receives a vector (already
;; projected from a Prediction by the caller) and annotates it.
;; Types close: Vector in, Vector out.
;;
;; The manager's discriminant learns: "tentative momentum at high
;; conviction" may mean noise, or it may mean an expert about to prove
;; itself. The data decides. We don't engineer the policy — we name
;; the distinction and let the geometry discover the policy.
(define (gate opinion-vector expert-atom proven?)
  (let ((status (if proven? (atom "proven") (atom "tentative"))))
    (bundle opinion-vector (bind expert-atom status))))

;; The caller composes: predict → opinion → gate
;;
;;   (let* ((prediction   (predict jrnl thought))
;;          (opinion-vec  (opinion prediction expert-atom))
;;          (annotated    (gate opinion-vec expert-atom (curve-valid? jrnl))))
;;     annotated)
;;
;; Each step has an honest type:
;;   predict:  Journal × Vector → Prediction
;;   opinion:  Prediction × Vector → Vector  (domain-specific projection)
;;   gate:     Vector × Vector × Bool → Vector  (generic annotation)

;; Consumers filter by reading the annotation:
;;   Manager: (filter (lambda (msg) (cosine (bind msg (atom "credibility")) (atom "proven"))) messages)
;;   Risk:    (identity messages)  ;; sees everything, proven and tentative
;;   Ledger:  (identity messages)  ;; records everything
