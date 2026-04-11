# Resolution: Proposal 002 — Pipes as Forms

**Date:** 2026-04-11
**Decision:** ACCEPTED — two forms + three verbs

## The designers

**Hickey:** Two forms: `defpipe` + `defprocess`. Drop defservice,
drain, select-ready. Capacity on the pipe. Loop explicit. Name the
constant, not the loop.

**Beckman:** Three forms: `defpipe` + `defprocess` + `defservice`.
Keep drain as a form (wards need it). Loop implied. Add deftopology
for ward verification.

## The decision

Two forms: `defpipe` and `defprocess`. Hickey wins on count — a
service is a process with multiplexed clients. Topology is data.

Three host verbs: `send`, `recv`, `try-recv`. Operations on pipes.

Capacity on the pipe (both agreed).
Loop explicit (Hickey's argument: hiding the defining characteristic
is hiding what matters).
Drain is a pattern, not a form (name the constant, the loop is five
lines of existing forms).
select-ready stays in the host (maps to crossbeam's Select).

The language grows by two declaration forms and three verbs.
