# Review: Rich Hickey

Verdict: ACCEPTED

---

## Why This Is Different

I rejected `defprocessor` because it was the callee declaring "I am a reducer." That is the function bragging about how it will be used. The function should not know. The function should not care. A function takes arguments and returns a value. The caller decides what to do with that value.

`fold` is the caller's expression. The function `heartbeat` remains a `define` with two arguments. It returns a value. It does not know it is being folded. It does not know there is a stream. It does not know there is a loop. It is a function. The fold is outside, where control belongs.

This is the correct inversion. Beckman saw it. The proposal executes it cleanly. My objection to Proposal 001 was not "the language does not need stateful iteration." My objection was "the function should not declare its own iteration context." Those are different objections. `fold` resolves the second without reintroducing the first.

## What the Proposal Gets Right

**The gap is real.** I said in my review of 001 that `(state, event) -> state` is already sufficient. It is sufficient as a *function*. But the language has four iteration forms -- `for-each`, `map`, `filter`, `filter-map` -- and all four are stateless. The only way to thread state across iterations today is a mutable closure over `for-each`, and the language does not have `set!`. So the gap is not theoretical. You literally cannot express a fold in wat without reaching for a primitive that encapsulates one (journal) or dropping to the runtime.

I missed this in my review of 001. I was correct that the function shape was fine. I was wrong that nothing else was needed. The function shape is the step function. The fold is the thing that drives it. The language names the step function (`define`). It should also name the driver.

**The form is minimal.** Three arguments: step function, initial state, collection. One result: final state. No metadata. No annotations. No declaration of "I am a processor." It is exactly as complex as `map` -- a higher-order function that iterates -- plus one argument for the accumulator seed. If `map` belongs in the control forms, `fold` belongs in the control forms.

**The function stays ignorant.** This is the test. The heartbeat example on page 3 is the same `define` I wrote in my review of 001. Same two arguments. Same returned state. The only difference is that the caller writes `(fold heartbeat initial-state candle-stream)` instead of the runtime calling it in an implicit loop. The function did not change. The language gained a word. That is the right trade.

## What I Want Tightened

**Section 6, Question 1 is a trap.** The proposal asks whether `fold` should replace `map`, `filter`, and `for-each` since they are all derivable from `fold`. No. Absolutely not. `map` communicates "I transform each element." `filter` communicates "I select elements." `fold` communicates "I carry state across elements." These are different intentions. That they are algebraically related does not mean they should collapse into one form. Simplicity is not minimality. Simplicity is one concept per form and one form per concept. Keep all five.

**Section 6, Question 3: do not add `scan`.** Not yet. `scan` is useful, but it is derivable from `fold` by making the accumulator a pair of `(state, list-of-intermediates)`. If the need becomes concrete, add it then. Right now it would be speculative surface area.

**Section 6, Question 5 needs a decision, not a question.** "Lists or streams?" is not something to leave open. The answer is: `fold` operates on whatever the language calls a sequence. If that is a list today and a lazy stream tomorrow, the form does not change. The abstraction is "a thing you can iterate." Do not bifurcate the form. Do not add `fold-stream` alongside `fold-list`. One `fold`. The compiler deals with the backing representation.

**Section 6, Question 2: left fold only.** Right fold is for lazy languages and infinite data structures. Wat compiles to Rust. The data is finite. The processing is eager. Left fold. Do not add `fold-right`. If someone needs right fold, they reverse the list and left-fold. That is a composition, not a form.

## On Beckman's Algebra

Beckman's review is characteristically precise. He says the journal is a coalgebra, the fold is the catamorphism, channels are the anamorphism, and together they form a hylomorphism. This is all correct. And it is exactly why `fold` is the right form.

My review of 001 said the fold does not belong in the language. Beckman demonstrated that it already IS in the language -- hidden inside `journal`, hidden inside the runtime's heartbeat loop. The question was never "should the fold exist?" The fold exists. The question was "should the language name it?" My answer was no, because the proposal named it by welding it to the function. Beckman's answer was yes, but name it as a *control form* that the function does not see. That is the answer.

I was wrong about one thing: I said the entry point is a build concern, like a port number. That is true for deployment. But `fold` is not about deployment. It is about *expression*. The programmer writes `(fold heartbeat initial-state candle-stream)` because that is what the program *means*. It means: apply this function repeatedly, threading state. That meaning belongs in the language, not in a config file.

## On the Primitive Count

The proposal does not add a seventh primitive. It adds a fifth control form alongside `for-each`, `map`, `filter`, and `filter-map`. The six primitives remain six. The algebra is untouched. `fold` does not participate in the algebra. It frames the algebra's application over time. This is the correct layer for it.

## The Test

Can I still test the heartbeat by calling it with one state and one event? Yes. The function is unchanged. `fold` is the caller. The function is the callee. They are decoupled.

Can the compiler see the iteration structure? Yes. `fold` gives it the anchor that `for-each`-with-mutation could not.

Does it complect anything? No. The step function is separate from the fold form, which is separate from the collection. Three arguments, three concerns, three separate things.

Does it add a concept every reader must learn? Yes, but it is a concept every programmer already knows. `fold` is `reduce`. It is `inject`. It is `foldl`. It is the most universal iteration pattern in programming. Naming it does not add complexity. Leaving it unnamed adds confusion.

## Decision

Add `fold` to the Iteration section of LANGUAGE.md. Left fold. Three arguments. Returns the final accumulator. Do not add `scan`, `fold-right`, or any variant. One form.

The language had a gap. This fills it. Nothing more, nothing less.

---

*I said "do not add any form whose purpose is to tell the compiler this function is special." `fold` does not do that. It tells the compiler this call site is a fold. The function remains ordinary. That is the distinction I should have made the first time.*
