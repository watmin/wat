;; ── std/patterns — derived patterns from core ───────────────────────
;;
;; Patterns that compose the six primitives into higher-level concepts.
;; Not new algebra — named compositions.

;; Gate: annotates a prediction with credibility status.
;; The message always flows. The consumer decides what credibility means.
;; The filter is a thought, not a suppression.
;;
;; The manager's discriminant learns: "tentative momentum at high
;; conviction" may mean noise, or it may mean an expert about to prove
;; itself. The data decides. We don't engineer the policy — we name
;; the distinction and let the geometry discover the policy.
(define (gate journal thought threshold)
  (let ((prediction (predict journal thought))
        (status (if (> (curve journal) threshold)
                    (atom "proven")
                    (atom "tentative"))))
    (bundle prediction (bind (atom "credibility") status))))

;; Consumers filter by reading the annotation:
;;   Manager: (filter (lambda (msg) (cosine (bind msg (atom "credibility")) (atom "proven"))) messages)
;;   Risk:    (identity messages)  ;; sees everything, proven and tentative
;;   Ledger:  (identity messages)  ;; records everything
