# Proposal 001: Multi-Asset Desks and Inter-Desk Communication

Status: DRAFT -- awaiting datamancer review before /designers

---

## 1. The Current State

Wat has six primitives: `atom`, `bind`, `bundle`, `cosine`, `journal`, `curve`. The runtime is a sequential heartbeat loop. One asset (BTC). One desk of experts. One manager. One treasury.

The heartbeat in `enterprise.wat` is a single function call chain:

```scheme
(define (heartbeat candle-idx candles vm experts generalist manager risk treasury)
  (let* ((expert-preds (map (lambda (e) (e candles vm candle-idx)) experts))
         (mgr-pred     (manager expert-preds gen-pred candle))
         (risk-mult    (risk treasury positions expert-preds))
         (_            (treasury-execute treasury mgr-pred risk-mult ...))
         (_            (manage-positions ...))
         (_            (learn ...)))
    (record-all ledger candle-idx)))
```

Communication is specified in `std/channels.wat` as a declarative publish/subscribe table with typed channels and filter expressions. This is currently a design document -- the channels compile to sequential function calls within the heartbeat. No actual runtime channels exist. The `publish` and `subscribe` forms are syntactic sugar over direct function invocation.

What works:
- The six primitives compose cleanly. The algebra is a monoid under bundle (superposition), and bind is the group operation (self-inverse).
- The journal learns. The curve validates. The gate controls flow.
- The sequential heartbeat is deterministic and debuggable.
- The channel specification captures who-talks-to-whom without runtime machinery.

## 2. The Problem

We need multiple assets (BTC, ETH, Gold). Each asset has its own desk of experts. Desks must be architecturally isolated -- an ETH expert must not leak into the BTC discriminant. A treasury reads all desk recommendations plus risk assessment to allocate capital across assets.

Three things cannot be expressed today:

**2a. Timing mismatch.** Candles arrive at different times per asset. BTC 5-minute candles do not align with ETH 5-minute candles. Gold trades on exchange hours. The current heartbeat assumes one clock. There is no way to say "process BTC when BTC is ready, process ETH when ETH is ready."

**2b. Desk isolation.** The current enterprise is one flat namespace. There is no scoping mechanism to say "these five experts, this manager, and this risk branch belong to the BTC desk, and they share nothing with the ETH desk except the treasury." The only isolation available is naming discipline (prefix atoms with "btc-" or "eth-"), which is convention, not architecture.

**2c. Cross-desk aggregation.** The treasury must read recommendations from N desks, each producing at its own cadence. Today the treasury is called once per heartbeat with one manager prediction. There is no way to express "collect the latest recommendation from each desk, regardless of when each desk last produced."

The proposed solution was to add four channel primitives: `channel`, `put!`, `take!`, `select!` -- async typed queues for inter-component communication. The motivation: components should process when ready, and backpressure handles timing mismatches.

## 3. The Proposed Change

### 3a. New primitive: `desk`

A desk is a scoped composition of experts, a manager, and a risk branch, all sharing a single clock source.

```scheme
(desk "btc"
  :clock   (candle-stream "BTC-USD" "5m")
  :experts (list
    (expert "momentum"  "momentum"  20000 500)
    (expert "structure" "structure" 20000 500)
    (expert "volume"    "volume"    20000 500)
    (expert "narrative" "narrative" 20000 500)
    (expert "regime"    "regime"    20000 500))
  :generalist (expert "generalist" "full" 20000 500)
  :manager    (manager 20000 500)
  :risk       (risk-branch 20000))
```

A desk is NOT a new primitive. It is a derived form -- a `let` binding that:
- Namespaces all atoms under the desk prefix (atoms inside the "btc" desk become "btc/momentum", "btc/structure", etc.)
- Binds a clock source that drives its heartbeat
- Produces a recommendation channel as its only external interface

What it compiles to in Rust: a struct containing journals, accumulators, and a `fn tick(&mut self, candle: &Candle) -> Option<Recommendation>`. No threads. No async. A function that the outer loop calls when data arrives.

### 3b. New channel primitives: `channel`, `put!`, `take!`, `select!`

```scheme
;; Declare a typed channel with optional buffer depth
(channel "btc-recommendations" :type desk-recommendation :depth 1)

;; Produce a value into a channel (non-blocking, overwrites if depth=1)
(put! "btc-recommendations" recommendation)

;; Consume the latest value from a channel (non-blocking, returns last or nothing)
(take! "btc-recommendations")

;; Wait for any of N channels to have a value, process the first available
(select!
  ("btc-recommendations" rec  (process-btc rec))
  ("eth-recommendations" rec  (process-eth rec))
  ("gold-recommendations" rec (process-gold rec)))
```

The `!` suffix denotes an effectful operation. These are the only forms in wat that have side effects beyond journal observation.

What they compile to in Rust: `channel` becomes a `Cell<Option<T>>` (depth=1) or `VecDeque<T>` (depth>1). `put!` writes. `take!` reads and clears. `select!` is a match over `take!` results -- no OS-level select, no async runtime. It is a sequential scan of mailboxes.

### 3c. The multi-asset heartbeat

```scheme
;; Each desk ticks on its own clock
(define desks
  (list
    (desk "btc"  :clock (candle-stream "BTC-USD" "5m")  ...)
    (desk "eth"  :clock (candle-stream "ETH-USD" "5m")  ...)
    (desk "gold" :clock (candle-stream "XAU-USD" "1h")  ...)))

;; The outer loop: one iteration per any-asset candle arrival
(define (heartbeat-multi event desks treasury)
  ;; Tick whichever desk the event belongs to
  (let ((desk (find-desk desks (asset event))))
    (when desk
      (let ((rec (tick desk (candle event))))
        (when rec (put! (recommendation-channel desk) rec)))))

  ;; Treasury reads all latest recommendations
  (let ((recs (filter-map (lambda (d) (take! (recommendation-channel d))) desks)))
    (when (not (null? recs))
      (treasury-allocate treasury recs))))
```

### 3d. What changes in the existing spec

- `std/channels.wat`: The existing declarative subscription table remains as documentation of within-desk wiring. The new channel primitives handle cross-desk communication.
- `core/primitives.wat`: No change. The six primitives remain six. `channel`, `put!`, `take!`, `select!` are stdlib, not corelib.
- `examples/enterprise.wat`: The single-asset heartbeat becomes one desk. A new `enterprise-multi.wat` shows the multi-desk composition.

## 4. The Algebraic Question

**Does `channel` compose with the existing monoid?**

No. Channels introduce a new algebraic structure: a mailbox. A mailbox is not a vector. You cannot `bind` a channel to a vector. You cannot `bundle` two channels. Channels live outside the VSA algebra entirely.

The relationship is: the algebra operates WITHIN a desk (vectors, journals, curves). Channels operate BETWEEN desks (typed messages). These are two separate algebras:

- **Inside a desk**: the VSA monoid. `bundle` is the operation. Vectors are the carrier set. `cosine` is the measurement.
- **Between desks**: a mailbox algebra. `put!` produces. `take!` consumes. `select!` multiplexes. Messages (not vectors) are the carrier set.

Is there a natural transformation? Yes, but it is one-directional. A desk produces a `Recommendation` (a message) from its internal vector algebra. The treasury consumes messages. The boundary is the `tick` function: vectors go in, a message comes out. Messages never become vectors (the treasury does not encode recommendations into hyperdimensional space -- it reads structured data).

**Does `channel` compose with the state monad (journal)?**

No. Journals accumulate observations and produce predictions -- they are stateful but internal. Channels transport messages between components -- they are stateful but external. A journal never reads from a channel. A channel never observes a journal. They are orthogonal.

**What algebraic structure IS a channel?**

A bounded queue is a comonoid under take (you can split a message off) but not a monoid under put (two puts don't compose into one put). More practically: channels are the IO monad. They are where pure algebra meets the impure world of timing and inter-component effects.

## 5. The Simplicity Question

**Is this simple or easy?**

The `desk` form is simple. It is scoping -- a `let` that namespaces atoms and binds a clock. It does not interleave new concepts. It could be expressed today with naming discipline; the form just makes the discipline structural.

The channel primitives (`channel`, `put!`, `take!`, `select!`) are easy, not simple. They are familiar (every concurrent system has channels), but they complect three things:

1. **Timing** -- when does a component run? (clock-driven vs. data-driven)
2. **Buffering** -- what happens when a producer is faster than a consumer? (depth, backpressure)
3. **Multiplexing** -- how does a consumer choose among multiple sources? (select)

**Could the existing primitives solve it differently?**

Yes. Consider the alternative: no channels at all.

```scheme
;; Alternative: the outer loop is just a bigger sequential heartbeat
(define (heartbeat-sequential candle-idx asset-candles vm desks treasury)
  (let* ((recs (filter-map
                 (lambda (desk)
                   (let ((candle (latest-candle asset-candles (asset desk) candle-idx)))
                     (when candle (tick desk candle))))
                 desks)))
    (when (not (null? recs))
      (treasury-allocate treasury recs))))
```

This requires no new primitives. The outer loop polls each desk. Each desk ticks only when it has a new candle (returns `nothing` otherwise). The treasury aggregates whatever is available.

The cost: the outer loop must know about all desks and their clock cadences. The benefit: no new algebraic structure. No effects. No `!` forms. Pure sequential composition.

**What is being complected by channels?**

Channels complect the communication topology with the execution model. Today, the topology is implicit in the function call graph (who calls whom). With channels, the topology becomes explicit (who publishes to what channel) but the execution model becomes implicit (when does a consumer run? when there is a message? every heartbeat? on select?).

The existing `std/channels.wat` already has this tension: it declares a pub/sub topology but compiles to sequential calls. The proposed channel primitives would make the topology real but would need to answer: what drives the loop?

## 6. Questions for Designers

1. **Should desks be a language form or a naming convention?** The `desk` form provides atom namespacing and clock binding. The alternative is pure convention: prefix all BTC atoms with "btc/", pass the clock explicitly. Is structural isolation worth a new form?

2. **Are runtime channels necessary, or is polling sufficient?** The sequential alternative (each heartbeat, poll each desk for new data) requires no new primitives. Channels add expressiveness for "process when ready" semantics. For the known use case (3-5 assets, all on regular candle intervals), is polling adequate?

3. **If channels are added, should they be in stdlib or corelib?** The proposal places them in stdlib. But they introduce effects (`!` forms) that no other stdlib form has. Does the presence of effects warrant a separate category -- neither core algebra nor standard library, but an IO layer?

4. **Should the treasury encode desk recommendations into vectors?** The proposal assumes the treasury reads structured messages, not vectors. But the enterprise pattern is: encode everything, let the algebra find structure. Should desk recommendations be encoded so the treasury can learn which desk combinations are healthy?

5. **Is `select!` necessary, or is `filter-map` over `take!` sufficient?** The `select!` form implies "wake on first available" semantics. In a sequential runtime, it reduces to iterating over channels and taking the first non-empty one. Is the separate form justified, or is it false concurrency?

6. **What is the clock model?** Today: one heartbeat, one clock. The proposal implies multiple clocks (one per asset). Who drives the outer loop? Options: (a) fastest clock ticks everything, (b) event-driven per asset, (c) wall clock at fixed interval polling all feeds. This is an execution model question, not a language question -- but the language must be compatible with the answer.

7. **Does desk isolation extend to the VectorManager?** Each desk needs deterministic atom-to-vector mappings. If desks share a VectorManager (same seed), atom namespacing ("btc/momentum" vs "eth/momentum") provides isolation. If desks have separate VectorManagers, atoms can collide in name but not in vector space. Which is correct?
