;; ── std/fields — RETIRED ──────────────────────────────────────────────
;;
;; (field struct-name field-name computation) has been retired.
;; See proposal 014 (protocols). defprotocol + satisfies subsume it.
;;
;; The field form treated stream processors as struct properties.
;; Indicators aren't properties of candles — they're independent fold
;; steps with their own state. The protocol declares the interface.
;; The struct holds the state. The step function advances it.
;;
;; This file is kept for historical reference. Do not use (field ...).
