;; ── std/scalars — scalar encoding into vector space ─────────────────
;;
;; Maps continuous values into the algebra.

;; Log scale — equal ratios = equal similarity.
;; Use for: orders of magnitude (ATR, volume, prices).
(encode-log value) → Vector

;; Linear scale — proportional mapping in [0, scale].
;; Use for: fractions, ratios, [0,1] values.
(encode-linear value scale) → Vector

;; Circular scale — endpoint wraps to start.
;; Use for: time-of-day, day-of-week, angles.
(encode-circular value period) → Vector
