;; ── common vocabulary (stdlib) ──────────────────────────────────────
;;
;; Generic atoms that any wat program might use.
;; Domain-specific atoms belong in the application, not here.

;; ── Gate status ─────────────────────────────────────────────────────
;; Annotations on messages. Consumers filter on these.
(atom "proven")       ; source has validated its curve
(atom "tentative")    ; source has NOT validated its curve

;; ── Predicates ──────────────────────────────────────────────────────
;; Static comparisons.
(atom "above") (atom "below") (atom "at")
;; Crossing events.
(atom "crosses-above") (atom "crosses-below")
;; Contact events.
(atom "touches") (atom "bounces-off")

;; ── Direction ───────────────────────────────────────────────────────
;; Generic directional atoms.
(atom "up") (atom "down") (atom "flat")

;; ── Temporal ────────────────────────────────────────────────────────
;; Generic time-related predicates (not specific schedules).
(atom "beginning") (atom "ending")
(atom "before") (atom "after") (atom "during")

;; ── Logical ─────────────────────────────────────────────────────────
(atom "nothing")      ; absence of signal — the null thought
(atom "open")         ; something has started
(atom "active")       ; something is in progress
(atom "closed")       ; something has completed
