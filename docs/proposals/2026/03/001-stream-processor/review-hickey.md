# Review: Rich Hickey

Verdict: REJECTED

---

## The Answer

None of the three options are needed. A function `(state, event) -> state` is already sufficient. But the proposal is confused about *why*, so let me be precise.

## What the Proposal Gets Right

The proposal correctly identifies that the enterprise is a reducer. It correctly identifies that `(state, event) -> state` is the right shape. It then spends 170 lines arguing that the language needs a form to *declare* this shape.

This is backwards. You found the answer in Section 1 and then argued yourself out of it.

## What the Proposal Gets Wrong

### The 10-argument problem is not a stream problem

The heartbeat takes 10 arguments. The proposal frames this as "which are state, which are event, which are config?" and concludes that a processor form would solve it by separating these concerns.

No. The 10-argument problem is a *data* problem. You have a bag of positional arguments where you should have a value. Put the enterprise state in a map:

```scheme
(define (heartbeat state event)
  (let* ((expert-preds (map (lambda (e) (e (:candles event) (:vm state) (:candle-idx event)))
                            (:experts state)))
         ;; ...
         )
    (assoc state :ledger (record-all (:ledger state) (:candle-idx event)))))
```

Two arguments. State is a value. Event is a value. The function returns a new state value. You already have `let*`. You already have `define`. You need nothing else except the discipline to pass data as data instead of as positional arguments.

This is the oldest trick. It is not a language design insight. It is a Tuesday.

### The fold does not belong in the language

The proposal asks: "Is the fold relationship a language concern or a runtime concern?"

It is a caller's concern. The function `(state, event) -> state` does not know or care whether it is being folded. It does not know if there is one event or a million. It does not know if the events come from a file, a WebSocket, or a test harness. This ignorance is a *virtue*. It is the reason the function is testable, composable, and reusable.

The moment you write `defprocessor`, the function knows it is being folded. You have complected the computation with its driver. You have taken a pure function and welded it to a runtime topology. The proposal itself identifies this in Section 5 ("Option A complects: function definition + state type declaration + event type declaration + runtime entry point. Four concerns in one form.") and then proceeds to consider Options B and C anyway.

Option B (convention) adds nothing. That is correct. Adding nothing is the right move when nothing is missing.

Option C (a `processor` declaration) is the most insidious. It appears minimal. "Just one form." But it exists solely to tell the compiler something the compiler should derive from usage. If the Rust runtime calls `heartbeat` in a loop, the compiler knows it is a reducer *because the runtime calls it in a loop*. The declaration is redundant information. Redundant information is not simple. It is a second source of truth that can diverge from the first.

### The compilation argument is wrong

The proposal says: "Compilation has no anchor. The compiler must know which function is the reducer."

The compiler does not need an anchor in the language. It needs a build configuration. "The entry point is `heartbeat`" is a deployment fact, like "the port is 8080." You do not put the port number in the language. You do not put the entry point in the language. You put it in the thing that drives the language.

A `main` function in C is a convention enforced by the linker, not by the language grammar. A `defprocessor` would be as if C required `defmain` instead of just naming a function `main` and letting the toolchain find it.

### Channels are already the stream abstraction

The enterprise already has `publish` and `subscribe`. The channels ARE the stream declaration. The proposal asks in Question 3 whether channels become redundant if you add `defprocessor`. The answer is the converse: channels make `defprocessor` redundant. The heartbeat publishes to channels. The runtime subscribes to the candle stream and calls the heartbeat. This is already declared. It is already in the language. The proposal is asking to add a second way to say what the channels already say.

## What You Should Do Instead

1. **Make state a value.** Replace the 10 positional arguments with `(heartbeat state event)` where state is a map. This is a refactor, not a language change.

2. **Make the entry point a build concern.** The wat compiler takes a flag or config: `--entry heartbeat`. Done. No language form needed.

3. **If you want type safety on state vs event**, use the optional type annotations you already have:

```scheme
(define (heartbeat [state : EnterpriseState] [event : Candle]) : EnterpriseState
  ...)
```

This is Option C minus the `(processor ...)` declaration. The types document the contract. The compiler enforces the shape. No new form.

4. **Do not add `defprocessor`.** Do not add `processor`. Do not add any form whose purpose is to tell the compiler "this function is special." Functions are not special. Functions are functions. The caller decides how to call them. That is the entire point of functions.

## The Deeper Issue

The six primitives are good. They are good because each one does one thing that cannot be derived from the others. `atom` names. `bind` relates. `bundle` superposes. `cosine` measures. `journal` learns. `curve` evaluates.

A processor form does not meet this bar. It does not do something that cannot be done with existing forms. It packages something that is already expressible (`define` + convention) into a form that is more convenient but less simple.

Convenience is a debt you pay in understanding. Every new form in a language is a concept every reader must learn, every tool must handle, every future proposal must compose with. The cost is permanent. The convenience is immediate. This tradeoff almost never favors the new form.

You have six primitives. That is a beautiful number. Do not make it seven for a problem that is solved by passing a map instead of ten positional arguments.

---

*Simple made easy: the function is already the right abstraction. The data layout is the problem. Fix the data, not the language.*
