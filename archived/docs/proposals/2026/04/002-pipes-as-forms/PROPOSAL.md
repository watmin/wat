# Proposal 016 — Pipes as Forms

**Date:** 2026-04-11
**Author:** watmin + machine
**Status:** PROPOSED

## The gap

The wat language has `pmap` and `pfor-each` — parallel iteration over
independent data. These compile to `par_iter` in Rust. They express:
"each item is independent, process them on all cores."

The enterprise also has pipes — bounded and unbounded channels between
persistent threads. Observer threads, broker threads, the encoder
service, the log service. Each is a process that owns its end of a
pipe. Each blocks on its input, computes, and sends on its output.
The backpressure IS the synchronization.

The wat cannot express this. The encoder-service.wat and log-service.wat
describe channels in pseudocode: `(bounded 1)`, `(send tx value)`,
`(recv rx)`, `(try-recv rx)`, `(select-ready pipes)`. These are not
real language forms. They are prose wearing parentheses.

The Rust implements CSP — communicating sequential processes via
crossbeam channels. The wat cannot specify it. The gap means:
- The ignorant cannot verify pipe architecture from the wat
- The inscribe cannot generate pipe code from the wat
- The wat is incomplete for systems with persistent threads

## What we need

The enterprise has four kinds of concurrent entities:

1. **Persistent processes** — observer threads, broker threads. They
   live for the duration of the run. They own mutable state. They
   communicate through channels.

2. **Service processes** — encoder service, log service. Single-threaded
   event loops with N client pipes. They own shared resources (cache,
   DB connection).

3. **Parallel phases** — `pmap` over independent data. No channels.
   No persistent state. Already expressed in wat.

4. **The fold driver** — the main thread. Routes candles. Collects
   results. The heartbeat.

Kinds 1 and 2 have no wat form. Kind 3 does (`pmap`). Kind 4 is
the `fold` form from Proposal 002.

## The proposed forms

### `defpipe` — a typed boundary between two processes

```scheme
(defpipe obs-input
  :capacity (bounded 1)
  :carries  (Candle Arc<Vec<Candle>> usize))

(defpipe obs-output
  :capacity (bounded 1)
  :carries  (Vector Prediction f64 Vec<(ThoughtAST Vector)>))

(defpipe obs-learn
  :capacity unbounded
  :carries  (Vector Direction f64))
```

A pipe declares: what crosses the boundary, and how much backpressure.
`bounded 1` = the sender blocks until the receiver reads. This IS the
synchronization — no separate sync needed. `unbounded` = fire and forget.

### `defprocess` — a persistent thread with pipe endpoints

```scheme
(defprocess observer-thread
  :reads  (obs-input obs-learn)
  :emits  obs-output
  :state  MarketObserver
  :body
    (loop
      ;; Drain learning signals (bounded by MAX_DRAIN)
      (drain obs-learn MAX_DRAIN
        (lambda (thought direction weight)
          (resolve (:state) thought direction weight recalib)))
      ;; Receive candle, encode, observe, send
      (let (((candle window encode-count) (recv obs-input)))
        (let* ((facts (market-lens-facts (:lens (:state)) candle window))
               ((thought misses) (incremental-encode (:state) facts encoder))
               (result (observe (:state) thought misses)))
          (send obs-output (result))))))
```

A process declares: what it reads, what it emits, what state it owns.
The body is a loop over the input pipe. `drain` reads up to N from
an unbounded pipe (the learning signals). `recv` blocks on the input.
`send` pushes to the output.

### `defservice` — a single-threaded event loop with N clients

```scheme
(defservice encoder-service
  :clients N
  :protocol
    (defpipe lookup  :capacity (bounded 1) :carries ThoughtAST)
    (defpipe answer  :capacity (bounded 1) :carries (Option Vector))
    (defpipe install :capacity unbounded    :carries (ThoughtAST Vector))
  :state (LruCache ThoughtAST Vector)
  :body
    (loop
      (for-each client (:clients)
        (when-let ((ast (try-recv (:lookup client))))
          (send (:answer client) (get (:state) ast)))
        (when-let (((ast vec) (try-recv (:install client))))
          (set! (:state) ast vec)))
      (when-idle (select-ready (:all-pipes)))))
```

A service declares: how many clients, what pipes each client gets,
and the event loop body. `try-recv` is non-blocking. `select-ready`
blocks until any pipe has data.

### `drain` — bounded consumption from an unbounded pipe

```scheme
(drain pipe max-count
  (lambda (args...) body))
```

Reads up to `max-count` items from an unbounded pipe. Non-blocking.
Returns when the pipe is empty or the count is reached. This is the
MAX_DRAIN pattern — the CRDT convergence lever.

### `select-ready` — block until any pipe has data

```scheme
(select-ready pipes)
```

The zero-CPU idle wait. Blocks until at least one pipe in the set
has data. Returns. The caller then drains with `try-recv`.

## Questions for the designers

1. Are `defpipe`, `defprocess`, and `defservice` three forms? Or is
   `defprocess` sufficient for both persistent processes and services
   (a service is just a process with N clients)?

2. Should `drain` be a form or a pattern? The body is always
   `(while drained < max (try-recv pipe) → apply → inc drained)`.
   Is naming it worth the language growth?

3. The pipe capacity (`bounded 1` vs `unbounded`) determines the
   scheduling semantics. Should this be on the pipe declaration or
   on the process that uses it?

4. The process body is a loop. Should `loop` be explicit or implied
   by `defprocess`? A process that doesn't loop is just a function.

5. Does this complect the wat language? The six primitives (atom,
   bind, bundle, cosine, reckoner, curve) are the algebra. The
   pipes are the plumbing. Should the plumbing live in the same
   language as the algebra?
