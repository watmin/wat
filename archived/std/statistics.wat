;; ── std/statistics — numeric helpers for the pre-algebra layer ────────
;;
;; Pure arithmetic over lists. These produce Floats that feed
;; encode-linear or fact/scalar. They do not touch the vector algebra.
;;
;; Tempered: multi-moment computation shares a single pass where possible.

(define (mean xs)
  (if (empty? xs) 0.0
      (/ (fold + 0.0 xs) (len xs))))

(define (variance xs)
  "Population variance. One pass for mean, one pass for deviations."
  (if (empty? xs) 0.0
      (let ((m (mean xs)))
        (/ (fold (lambda (sum x) (+ sum (* (- x m) (- x m)))) 0.0 xs)
           (len xs)))))

(define (stddev xs)
  (sqrt (variance xs)))

(define (moments xs)
  "Compute mean, variance, and stddev in two passes (not four).
   Returns (mean, variance, stddev). Use when you need multiple moments."
  (if (empty? xs) (list 0.0 0.0 0.0)
      (let* ((n (len xs))
             (m (/ (fold + 0.0 xs) n))
             (v (/ (fold (lambda (sum x) (+ sum (* (- x m) (- x m)))) 0.0 xs) n))
             (s (sqrt v)))
        (list m v s))))

(define (skewness xs)
  "Population skewness. Uses moments to avoid redundant passes."
  (let ((mom (moments xs)))
    (let ((m (first mom)) (s (nth mom 2)))
      (if (<= s 0.0) 0.0
          (/ (fold (lambda (sum x)
                     (let ((z (/ (- x m) s)))
                       (+ sum (* z z z))))
                   0.0 xs)
             (len xs))))))
