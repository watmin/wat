;; ── std/statistics — numeric helpers for the pre-algebra layer ────────
;;
;; Pure arithmetic over lists. These produce Floats that feed
;; encode-linear or fact/scalar. They do not touch the vector algebra.

(define (mean xs)
  (if (empty? xs) 0.0
      (/ (fold + 0.0 xs) (len xs))))

(define (variance xs)
  (if (empty? xs) 0.0
      (let ((m (mean xs)))
        (/ (fold (lambda (sum x) (+ sum (* (- x m) (- x m)))) 0.0 xs)
           (len xs)))))

(define (stddev xs)
  (sqrt (variance xs)))

(define (skewness xs)
  (let ((m (mean xs))
        (s (stddev xs)))
    (if (<= s 0.0) 0.0
        (/ (fold (lambda (sum x)
                   (+ sum (* (/ (- x m) s) (/ (- x m) s) (/ (- x m) s))))
                 0.0 xs)
           (len xs)))))
