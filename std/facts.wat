;; ── std/facts — the bridge between domain vocabulary and the algebra ──
;;
;; Four named compositions of atom + bind + encode-linear.
;; Any program that encodes domain knowledge into vectors uses these.

(require core/primitives)

;; Zone: "this indicator is in this state"
;; (fact/zone "rsi" "overbought") → bind(at, bind(rsi, overbought))
(define (fact/zone indicator zone)
  (bind (atom "at") (bind (atom indicator) (atom zone))))

;; Comparison: "A is above/below/crossing B"
;; (fact/comparison "above" "close" "sma50") → bind(above, bind(close, sma50))
(define (fact/comparison predicate a b)
  (bind (atom predicate) (bind (atom a) (atom b))))

;; Scalar: "this indicator has this continuous value"
;; (fact/scalar "williams-r" 0.73 1.0) → bind(williams-r, encode-linear(0.73, 1.0))
(define (fact/scalar indicator value scale)
  (bind (atom indicator) (encode-linear value scale)))

;; Bare: "this named condition is present"
;; (fact/bare "roc-accelerating") → atom(roc-accelerating)
(define (fact/bare label)
  (atom label))
