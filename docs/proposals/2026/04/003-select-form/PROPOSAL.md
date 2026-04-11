# Proposal 003 — The Select Form

**Date:** 2026-04-11
**Author:** watmin + machine
**Status:** PROPOSED
**Follows:** Proposal 002 (pipes resolved: defpipe, defprocess, send/recv/try-recv/select-ready)

## The problem

Proposal 002 gave us pipe forms. But the encoder service and log
service are not simple single-pipe processes. They are event loops
over N client pipe sets. The pattern:

1. Block until ANY pipe has data (select-ready)
2. Drain all ready pipes (try-recv loop)
3. If all pipes closed, exit
4. Repeat

Expressed with the current forms, this is ugly:

```scheme
(loop
  (let ((did-work false))
    (for-each-indexed (lambda (i (lk inst))
      (when (not (nth closed i))
        (match (try-recv lk)
          ((Some ast) (send (nth answers i) (get cache ast))
                      (set! did-work true))
          (None nil))
        (match (try-recv inst)
          ((Some (ast vec)) (set! cache ast vec)
                            (set! did-work true))
          (None nil))))
      clients)
    (when (every? closed) (break))
    (when (not did-work)
      (select-ready (build-pipe-list-somehow...)))))
```

This is implementation, not specification. The closed-tracking, the
did-work flag, the pipe list construction — all plumbing that hides
the intent. The intent is: "serve N clients, handle lookups and
installs, idle when no work."

## What we want

A form that says what the event loop DOES, not how it polls.

## Candidates

### A. `select` as a match-like form over pipes

```scheme
(select
  ((recv lk) => (lambda (ast)
    (send answer (get cache ast))))
  ((recv inst) => (lambda ((ast vec))
    (set! cache ast vec)))
  (:idle => (select-ready all-pipes))
  (:closed => (break)))
```

Each arm is a pipe + handler. The runtime checks all arms, fires
whichever has data. `:idle` fires when nothing was ready. `:closed`
fires when all pipes are disconnected. Like Clojure's `alt!` or
Go's `select`.

### B. `serve` as a higher-level service loop

```scheme
(serve clients
  :on-lookup  (lambda (client-idx ast)
    (send (:answer client-idx) (get cache ast)))
  :on-install (lambda (client-idx ast vec)
    (set! cache ast vec)))
```

One form. Declares the handlers. The runtime manages the event loop,
the idle blocking, the closed detection. The specification says WHAT
happens on each message type. The HOW is the runtime's problem.

### C. Keep `select-ready` as a verb, add `drain-all` as a pattern

```scheme
(loop
  (let ((work (drain-all clients
                :lookup  (lambda (ast) (send answer (get cache ast)))
                :install (lambda ((ast vec)) (set! cache ast vec)))))
    (when (all-closed? clients) (break))
    (when (not work) (select-ready (pipes-of clients)))))
```

`drain-all` iterates all client pipe sets, tries each named pipe,
calls the handler. Returns whether any work was done. The select-ready
and closed-check are still explicit.

### D. `defservice` after all (Beckman's original suggestion)

```scheme
(defservice encoder-service
  :clients N
  :pipes-per-client
    ((lookup  :capacity (bounded 1) :carries ThoughtAST)
     (answer  :capacity (bounded 1) :carries (Option Vector))
     (install :capacity unbounded   :carries (ThoughtAST Vector)))
  :state (Map ThoughtAST Vector)
  :handlers
    ((:lookup ast)  => (send :answer (get (:state) ast)))
    ((:install ast vec) => (set! (:state) ast vec)))
```

A service IS a different thing from a process. Hickey said topology
is data. Beckman said the N-indexed protocol is genuinely different.
The ugliness of the select loop is evidence for Beckman.

## Questions for the designers

1. Is the event loop a specification concern or an implementation
   concern? If specification: which form expresses it cleanly? If
   implementation: leave it to the Rust and let the wat just declare
   the handlers?

2. Go has `select`. Clojure has `alt!`. Erlang has `receive`. Each
   is a match over channels. Is that the right form for wat? Or is
   wat's job to declare the service (what it handles) and let the
   compilation target choose the event loop strategy?

3. Hickey rejected `defservice` in Proposal 002. The evidence since
   then (the ugly select loop) — does it change his position?

4. Should the N-client pattern be a form at all? Or should the wat
   specify one client's protocol and let the binary instantiate N
   copies? The multiplexing is a deployment decision.
