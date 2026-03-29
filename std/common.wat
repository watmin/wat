;; ── common vocabulary (stdlib) ──────────────────────────────────────
;;
;; Generic atoms that any wat program might use.
;; Domain-specific atoms belong in the application, not here.

;; ── Gate status ─────────────────────────────────────────────────────
;; Annotations on messages. Consumers filter on these.
(atom "proven")       ; source has validated its curve
(atom "tentative")    ; source has NOT validated its curve

;; ── Predicates ──────────────────────────────────────────────────────
;; Generic comparison relationships.
(atom "above") (atom "below")
(atom "crosses-above") (atom "crosses-below")
(atom "touches") (atom "bounces-off")
(atom "at")

;; ── Direction ───────────────────────────────────────────────────────
;; Generic directional atoms.
(atom "up") (atom "down") (atom "flat")

;; ── Temporal ────────────────────────────────────────────────────────
;; Generic time-related predicates (not specific schedules).
(atom "beginning") (atom "ending")
(atom "before") (atom "after") (atom "during")

;; ── Logical ─────────────────────────────────────────────────────────
(atom "null")         ; absence of signal
(atom "active")       ; something is in progress
(atom "closed")       ; something has completed
