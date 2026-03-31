# Proposal 001: Stream Processor

Status: REVIEWED — see review-hickey.md, review-beckman.md, RESOLUTION.md

Scope: **core** — proposing a new language form or rejecting the need for one.

---

## 1. The Current State

The wat language has six primitives: `atom`, `bind`, `bundle`, `cosine`, `journal`, `curve`. It has control forms (`define`, `let`, `if`, `match`, `for-each`, `map`, `filter`). It has a channel stdlib for publish/subscribe.

The existing enterprise program (`examples/enterprise.wat`) defines a `heartbeat` function that processes one event at a time:

```scheme
(define (heartbeat candle-idx candles vm
                   experts generalist manager risk treasury positions exit-expert)
  "The enterprise processes one candle. Everything flows from here."
  (let* ((expert-preds (map (lambda (e) (e candles vm candle-idx)) experts))
         ;; ... layers 2-6 ...
         )
    (record-all ledger candle-idx)))
```

The heartbeat is a function. The loop that calls it is implicit -- it lives outside the program, in the Rust runtime. The comment at the bottom says "every candle, the tree processes" but there is no language form that declares this relationship.

What works: the heartbeat function is clean. It takes state and an event, produces effects, returns. The enterprise IS a reducer. This is the correct architecture.

What is merely conventional: the name "heartbeat", the signature pattern `(state, event) -> state`, and the expectation that a caller will fold this function over a stream. None of this is declared in the language. A reader must understand the convention by reading comments and context.

## 2. The Problem

The enterprise is a reducer -- it processes one event at a time and updates its state. But the language has no way to say "I am a reducer." The fold relationship between the stream and the processor is invisible.

Concretely:

**2a. The interface is undeclared.** The heartbeat takes 10 arguments. Which are state (mutable across events)? Which are the event (fresh each tick)? Which are configuration (fixed at construction)? The signature does not distinguish these. A reader must trace the code to understand what flows through time and what arrives fresh.

**2b. The fold is implicit.** The Rust runtime knows to call heartbeat in a loop. But nothing in the wat program declares this intent. The program looks like a collection of function definitions with a heartbeat function that happens to be the entry point. "Call this function once per event" is a runtime contract that exists only in the programmer's head.

**2c. Compilation has no anchor.** When wat compiles to Rust, the compiler must know which function is the reducer, what its state type is, and what its event type is. Today this is hardcoded knowledge. If the language declared it, the compiler could derive the `impl` mechanically.

## 3. The Proposed Change

### Option A: A new language form -- `defprocessor`

```scheme
(defprocessor enterprise
  :state   { :experts    (list Expert)
             :generalist Expert
             :manager    Manager
             :risk       RiskBranch
             :treasury   Treasury
             :positions  (list Position)
             :ledger     Ledger }
  :accepts Event
  :on-event
    (fn [state event]
      (let* ((expert-preds (map (lambda (e) (e (candle event) (vm state))) (experts state)))
             (gen-pred     ((generalist state) (candle event) (vm state)))
             (mgr-pred     ((manager state) expert-preds gen-pred (candle event)))
             (risk-mult    ((risk state) (treasury state) (positions state) expert-preds))
             (_            (treasury-execute (treasury state) mgr-pred risk-mult (candle event)))
             (_            (manage-positions (positions state) (treasury state) (candle event)))
             (_            (learn (experts state) (generalist state) (manager state)
                                  (candle event) (pending state) (move-threshold state))))
        (record-all (ledger state) event)
        state)))
```

The runtime becomes:

```scheme
(reduce enterprise events initial-state)
```

This makes explicit:

- What the state is (the enterprise's mutable internals).
- What an event is (one tick of external data).
- What the fold function is (on-event).
- What the caller provides (the stream of events).

### Option B: No new form -- a signature convention

```scheme
;; The convention: a processor is any (define) whose first arg is state
;; and second arg is event, returning state.

(define (enterprise state event)
  "A reducer. State is the enterprise. Event is one tick."
  (let* ((expert-preds (map (lambda (e) (e (candle event) (vm state))) (experts state)))
         ;; ... same body ...
         )
    (record-all (ledger state) event)
    state))

;; The caller folds:
(fold enterprise initial-state events)
```

No new language form. The convention is: "a processor is a function `(state, event) -> state`." The compiler recognizes this by annotation or naming convention.

### Option C: A type annotation, not a form

```scheme
(define (enterprise [state : EnterpriseState] [event : Event]) : EnterpriseState
  ;; ... same body ...
  state)

;; Declare the entry point
(processor enterprise)  ; tells the compiler: this is the fold target
```

One new declaration (`processor`) that points at an existing function. Minimal syntax. The function itself is a normal `define`. The declaration is metadata for the compiler: "generate the event loop for this."

## 4. The Algebraic Question

**Does a processor form compose with the existing monoid (bundle/bind)?**

It is orthogonal. The processor does not participate in the vector algebra. It is a structural form -- it declares the fold topology, not a vector operation. Bundle composes vectors. Processor composes a function with a stream. They do not interact algebraically; they operate at different levels.

**Does it compose with the state monad (journal)?**

Yes, naturally. A journal IS state that evolves across events. The processor form makes explicit what the journal already assumes: that there is a stream of observations arriving one at a time. The journal's `observe`/`predict`/`decay` cycle is the inner fold. The processor is the outer fold that drives it.

**Does it introduce a new algebraic structure?**

If Option A: yes, a named form with `:state`, `:accepts`, `:on-event` slots. This is a record type with a distinguished method, not an algebraic structure. It does not have a monoid, a group, or a ring. It is structural scaffolding.

If Option B or C: no. It uses existing `define` and adds convention or a lightweight declaration.

## 5. The Simplicity Question

**Is this simple or easy?**

Option A (`defprocessor`) is easy. It packages multiple concerns into one form: state declaration, event type, fold function, and implicit runtime contract. It is convenient. But it complects the function definition with runtime metadata. A `defprocessor` cannot be called as a normal function -- it is a special form.

Option B (convention) is simple. It adds nothing to the language. But it relies on human discipline to maintain the `(state, event) -> state` shape. The compiler cannot verify the convention without external metadata.

Option C (`processor` declaration) is between the two. The function is a normal `define`. The declaration is a single form that says "this is the entry point." The function can still be called directly in tests. The compiler has its anchor.

**What is being complected?**

Option A complects: function definition + state type declaration + event type declaration + runtime entry point. Four concerns in one form.

Options B and C keep function definition separate from processor declaration. Option C adds one form. Option B adds zero forms.

**Could existing primitives solve it?**

The six primitives are about vector algebra. They do not address program structure. The control forms (`define`, `let`, etc.) address computation structure. The question is whether "I am a reducer over a stream" is a computation structure concern (belongs in control forms) or a deployment concern (belongs outside the language).

Argument for "outside the language": the Rust runtime already knows it is calling a function in a loop. The wat program does not need to know it is being folded. It just needs to be a pure function of the right shape. The fold is the caller's concern.

Argument for "inside the language": the heartbeat's 10 undifferentiated arguments are a real readability and correctness problem. Distinguishing state from event from config in the signature is a language concern, not a deployment concern.

## 6. Questions for Designers

1. **Is the fold relationship a language concern or a runtime concern?** The enterprise IS a reducer. Should the language declare this, or should the language just define a function and let the runtime decide how to call it? The six primitives are all about "what to compute." A processor form would be the first form about "how to drive the computation."

2. **Does state/event/config distinction belong in the type system or the form system?** The heartbeat takes 10 arguments. Some are state (mutate across events), some are event (fresh each tick), some are config (fixed at construction). The language currently has optional type annotations but no way to annotate argument roles. Is `(defprocessor :state ... :accepts ...)` the right way to express this, or would richer type annotations on `define` suffice?

3. **If we add a processor form, does the channel stdlib become redundant?** Channels declare producers and consumers with typed streams. A processor form declares a consumer with typed state and events. These overlap. If the language has `defprocessor`, do channels reduce to "processors that publish to named topics"? Or do channels serve a different purpose (intra-enterprise communication) that processors do not address (enterprise-to-stream relationship)?

4. **One processor or many?** The enterprise has one heartbeat. But what about a system with multiple independent reducers consuming the same stream? E.g., the enterprise reducer AND a monitoring reducer that only computes diagnostics. Should the language support declaring multiple processors, or is one entry point sufficient?

5. **Does the answer change for multi-desk?** Proposal 001 introduces `make-desk`, where each desk is effectively a sub-reducer dispatched by asset tag. If the language had `defprocessor`, would each desk be its own processor? Or is the enterprise still one processor that dispatches internally? The answer determines whether processor is a top-level-only form or a composable building block.

6. **Is Option C (a `processor` declaration pointing at a `define`) the right middle ground?** It adds one form. It does not complect function definition with runtime metadata. The function remains testable. The compiler gets its anchor. But is even this one form more than the language needs?
