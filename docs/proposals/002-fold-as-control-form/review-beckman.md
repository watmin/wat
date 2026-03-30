# Review: Brian Beckman

Verdict: ACCEPT

---

## What Happened

My conditional in the 001 review said: add `fold` as a control form, not `defprocessor`. This proposal does exactly that. It does it cleanly. The form is `(fold f init items)`, the step function is a normal `define` or `lambda`, the function does not know it is being folded. This is correct.

I want to address the six questions the proposal raises, because the answers matter more than the verdict.

## Question 1: Is fold essential or derivable?

The proposal notes that `map`, `filter`, and `for-each` can all be derived from `fold`. This is true. In the category of F-algebras over lists, `fold` is the universal morphism. The others are specializations.

But I would NOT replace the others with `fold`. Here is why. `map` says "I preserve structure." `filter` says "I preserve elements." `for-each` says "I discard results." These are semantic declarations. A reader who sees `map` knows the output list has the same length as the input. A reader who sees `(fold (lambda (acc x) (cons (f x) acc)) '() items)` must trace the lambda to reach the same conclusion.

Keep all five. `fold` is the general case. The others are named specializations that communicate intent. This is not redundancy -- it is vocabulary. A language with only `fold` is like a language with only `lambda` and no `define`. Correct but hostile.

## Question 2: Left fold or right fold?

Left fold. The proposal is right that a language compiling to Rust over finite streams has no use for lazy right folds. But I want to be precise about why.

A right fold over a list `[a, b, c]` computes `f(a, f(b, f(c, init)))`. The outermost application is on the first element. In a lazy language, this means you can produce output before consuming all input -- which is how Haskell implements `map` as a right fold that streams.

Wat compiles to Rust. Rust is strict. A right fold over a strict language traverses to the end before computing anything, consuming O(n) stack. It buys you nothing and costs you a stack frame per element.

Left fold computes `f(f(f(init, a), b), c)`. The innermost application is on the first element. In a strict language, this is a loop with constant stack. It is also the natural semantics for "accumulate state forward through time," which is what every wat program does.

Provide only left fold. Call it `fold`. Do not provide `fold-right`. If someone needs it later, they can reverse the list first. That composition is trivial and self-documenting.

## Question 3: Should fold return intermediate states?

No. `fold` returns the final accumulator. Period.

`scan` (the intermediate-state variant) is a different animal. A `scan` over n elements produces n+1 values. It is a `map` that carries state -- a hybrid. It is useful, but it is a separate form with different performance characteristics and a different return type.

If you add `scan`, add it later, as a separate proposal. Do not overload `fold`. A form that sometimes returns one value and sometimes returns a list is a form that nobody trusts.

## Question 4: Does naming fold change anything about journal?

This is the question I care about most. The answer is yes, but carefully.

The journal IS a fold. Its `observe` is the step function. Its accumulator pair is the state. The stream of `(thought, label, weight)` triples is the input. This is not a metaphor. It is a mathematical fact. The journal computes a catamorphism over the observation stream.

But the journal is an *encapsulated* fold. It hides its accumulator. You cannot inspect the buy and sell prototypes from outside. You cannot substitute a different step function. You interact through `observe` and `predict`. This encapsulation is a feature, not a limitation. The journal is a fold that has been packaged into a reusable component with a clean interface.

The documentation should say this explicitly:

> The journal is a specialized fold over observations. Its step function is `observe`. Its state is the accumulator pair. The enterprise heartbeat is a fold over candles. `fold` names the pattern that both share.

This does NOT mean journals can be replaced by raw folds. A raw `(fold observe-step initial-journal-state observations)` would expose the internal accumulator, bypass the recalibration logic, and break the discriminant extraction. The journal encapsulates the fold the way an object encapsulates state. The fold is the structural pattern. The journal is a specific, validated implementation of that pattern.

Making this connection explicit is the single most important thing this proposal does. It reveals the self-similarity: the enterprise is a fold whose step function contains sub-folds (the journals), and each journal is a fold whose step function contains algebraic operations (bind, bundle, cosine). Three levels. Same pattern. One name.

## Question 5: Streams or lists?

Both, but the language should not distinguish them syntactically.

A list is a stream that has been fully materialized. A stream is a list that has not yet been materialized. The `fold` form should accept anything iterable. The compiler decides whether to materialize or stream based on the source:

- `(fold f init some-list)` -- the list is in memory. The compiler emits a loop over the list.
- `(fold f init candle-stream)` -- the stream is lazy. The compiler emits an event loop that calls `f` on each arriving element.

The distinction is a compilation concern, not a language concern. The `fold` form is the same in both cases. The semantics are the same: apply `f` to each element, threading state. Whether the elements are all present or arrive one at a time is a property of the source, not of the fold.

This is exactly how Rust's `Iterator::fold` works. The iterator might be a `Vec::iter()` (in-memory) or a `Read::bytes()` (streaming). The fold does not care. The type system handles the distinction. Wat should follow the same principle: `fold` is the consumer. The producer determines materialization.

## Question 6: Is this the right time?

Yes. And the proposal itself explains why, though it buries the argument.

The language has six primitives and four iteration forms. The four iteration forms are `for-each`, `map`, `filter`, `filter-map`. All four are stateless. Every interesting wat program -- every enterprise, every journal, every agent -- is stateful. The stateful pattern has no name.

This is not an absence that might cause a problem someday. It is an absence that is causing a problem now. The heartbeat example in LANGUAGE.md takes 8 positional arguments because the language cannot express "thread this state through a sequence of calls." The resolution of Proposal 001 says to refactor the heartbeat to `(state, event)` -- but refactoring the signature only helps if there is a form to drive it. Without `fold`, the refactored heartbeat is a function that sits there waiting for someone to call it in a loop. The loop is still in the runtime, unnamed in the language.

Adding `fold` now, when the language has four iteration forms, costs almost nothing. The form is one line in LANGUAGE.md. The compilation is a loop. The semantics are well understood (it is a left fold, the same as in every functional language since ML). There is no future form that `fold` will conflict with, because `fold` is the universal iteration form -- everything else is a specialization.

Waiting costs more. Every new wat program written without `fold` will use `for-each` with a mutable closure (which the language does not have) or will push the fold into the runtime (which makes the language blind to its own structure). Each of these workarounds creates a precedent that becomes harder to undo.

## The Deeper Point

The proposal says: "`fold` does not participate in the algebra -- it frames the algebra's application."

I want to sharpen this. `fold` does not extend the algebra. It *completes the language*. The six primitives say what to compute. The existing control forms say how to structure a single computation (`let`, `if`, `match`) or how to apply a computation across a collection statelessly (`map`, `filter`, `for-each`). Nobody says how to apply a computation across a collection *with state*.

That gap is exactly the gap between a single inference and learning. A single call to `cosine` is inference. A fold of `observe` calls is learning. The journal bridges this gap internally, but the language cannot express it externally. Adding `fold` means the language can say what it already does.

This is what I meant in the 001 review when I said "the algebra lives in time." The primitives are timeless -- `bind`, `bundle`, `cosine` are pure functions. The fold is what introduces time. It says: apply these timeless operations in sequence, carrying what you learned forward. That is cognition. The language is about cognition. The language should be able to say this.

## One Concern

The proposal's Section 4 says fold composes with `bundle` and `bind` as step functions. The examples are clean:

```scheme
(fold bundle (zero-vector dims) vectors)
(fold bind identity-vector concepts)
```

But there is a subtlety. `bundle` is commutative (approximately, in high dimension). `bind` is associative but not commutative. A left fold over `bind` gives `bind(bind(bind(identity, a), b), c)` which equals `bind(identity, bind(a, bind(b, c)))` only because `bind` is associative. If someone introduces a non-associative step function, the left fold will silently produce order-dependent results.

The documentation should note that `fold` is a left fold and that the result depends on element order when the step function is not commutative. This is standard, but worth stating explicitly in a language where most operations (bundle, cosine) are approximately commutative and programmers may develop the habit of ignoring order.

## Verdict: ACCEPT

The proposal satisfies all four conditions from my 001 review:

1. `fold` is a control form, not `defprocessor`. Yes.
2. No state/event/config annotations. Yes -- currying handles config, the binary signature handles state/event.
3. No conflation with runtime deployment. Yes -- `fold` says "apply catamorphically," not "generate an event loop."
4. Acknowledge that `journal` is already a fold. The proposal says it in Section 4. The documentation should make it more prominent.

Add `fold`. One line in the iteration section. One compilation rule. One name for the pattern that already runs at every level of every wat program.

---

*The journal is a fold. The enterprise is a fold. The desk is a fold. Now the language can say so.*
