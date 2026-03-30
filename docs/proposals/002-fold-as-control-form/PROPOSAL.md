# Proposal 002: Fold as Control Form

Status: PROPOSED

Scope: **core** -- proposing a new control form for the wat language.

Origin: Beckman's review of Proposal 001. Hickey rejected `defprocessor` because it was the callee declaring "I am a reducer." Beckman agreed with the rejection but observed that the catamorphism exists unnamed at every level of every wat program. He proposed `fold` as the caller's expression -- the function stays ignorant.

---

## 1. The Current State

The wat language has four iteration control forms:

```scheme
(for-each fn list)       ; apply fn to each element, discard results
(map fn list)            ; apply fn to each element, collect results
(filter fn list)         ; select elements satisfying predicate
(filter-map fn list)     ; map + filter in one pass
```

All four iterate over a list. None of them carry state across iterations. They are the stateless iteration forms.

The language also has `journal`, which is stateful -- it accumulates observations over time, maintains a discriminant, and produces predictions. The journal IS a fold over observations. Its `observe` function is the step function. Its accumulator pair is the state. The stream of `(thought, label, weight)` triples is the input. But the fold is not named. It is implicit in the journal primitive's internal implementation.

The enterprise heartbeat is also a fold. It takes state and an event, produces new state. The Rust runtime calls it in a loop. But nothing in the language says so. The fold exists in the runtime, unnamed in the language.

Every wat program that processes a stream over time contains at least one fold. It is the most common structural pattern. It is the only one without a name.

## 2. The Problem

The language can express "do this to each element" (`for-each`), "transform each element" (`map`), and "select elements" (`filter`). It cannot express "accumulate state across elements."

Concretely:

**2a. The pattern is universal but unnamed.** The journal folds observations. The enterprise folds candles. A multi-agent system folds events dispatched to sub-folds. The pattern recurs at every level. Calling it `for-each` with a mutable closure is not naming it -- it is disguising it.

**2b. The compiler cannot see the iteration structure.** When `for-each` is used with a closure that mutates external state, the compiler sees a side-effecting loop. It cannot reason about the state threading. It cannot verify that the state flows correctly. It cannot fuse nested folds. A named `fold` form gives the compiler the structural information it needs.

**2c. The existing forms are incomplete.** `map`, `filter`, `for-each`, and `fold` are the four fundamental list operations in every functional language. Wat has three. The fourth is the one that carries state.

## 3. The Proposed Change

Add `fold` as a control form alongside `map`, `filter`, `for-each`, and `filter-map`.

```scheme
(fold f init items)
```

- `f` is a function `(accumulator, element) -> accumulator`
- `init` is the initial accumulator value
- `items` is a list (or stream)
- The result is the final accumulator value

### What it looks like

Summing a list:

```scheme
(fold (lambda (acc x) (+ acc x)) 0 values)
```

Building a frequency table:

```scheme
(fold (lambda (acc x) (assoc acc x (+ 1 (get acc x 0))))
      {}
      tokens)
```

Computing a prototype from labeled observations:

```scheme
(fold (lambda (acc obs)
        (if (eq? (label obs) target-label)
            (bundle acc (thought obs))
            acc))
      (zero-vector dims)
      observations)
```

### What it does NOT look like

It is NOT `defprocessor`. The step function is a normal `define` or `lambda`. It does not know it is being folded. The fold is the caller's expression. The function stays ignorant.

```scheme
;; The function: a normal define. Two arguments. Returns state.
(define (heartbeat state event)
  (let* ((expert-preds (map (lambda (e) (e (:candles event) (:vm state)))
                            (:experts state)))
         ;; ... layers 2-6 ...
         )
    (assoc state :ledger (record-all (:ledger state) event))))

;; The fold: the caller's declaration.
(fold heartbeat initial-state candle-stream)
```

The function `heartbeat` can be called directly in tests with a single state and event. It does not know about streams. It does not know about loops. It is a function.

### What changes in LANGUAGE.md

The Iteration section gains one line:

```scheme
;; Iteration
(for-each fn list)               ; side effect per element
(map fn list)                    ; transform each element
(filter fn list)                 ; select elements
(filter-map fn list)             ; map + filter
(fold f init items)              ; accumulate state across elements
```

### What the compiler does with it

`(fold f init items)` compiles to a loop:

```rust
let mut acc = init;
for item in items {
    acc = f(acc, item);
}
acc
```

The compiler can also apply fold fusion: if `f` contains an inner `map` or `filter`, the compiler can fuse them into a single pass. This optimization is possible BECAUSE the fold is named -- the compiler can see the structure.

## 4. The Algebraic Question

**Does `fold` compose with the existing monoid (bundle/bind)?**

Yes. `fold` with `bundle` as the step function IS prototype extraction:

```scheme
(fold bundle (zero-vector dims) vectors)
;; equivalent to (prototype vectors)
```

`fold` with `bind` as the step function IS sequential binding:

```scheme
(fold bind identity-vector concepts)
;; equivalent to binding a chain of concepts
```

The algebraic primitives are the operations. `fold` is the iteration structure that drives them across collections. They compose naturally because `fold` does not participate in the algebra -- it frames the algebra's application.

**Does it compose with the state monad (journal)?**

The journal IS a fold. `observe` is the step function. The accumulator pair is the state. Making this explicit does not change the journal's behavior. It makes the self-similarity visible:

```scheme
;; The journal is a fold over observations (encapsulated)
;; The enterprise is a fold over events (now expressible)
;; A desk is a fold over asset-tagged events (composable)
```

**Does it introduce a new algebraic structure?**

No. `fold` is a catamorphism -- a structural recursion scheme. It is not an algebraic primitive. It is a control form, like `let` or `if`. It tells the compiler how to iterate, not what to compute.

## 5. The Simplicity Question

**Is this simple or easy?**

Simple. `fold` has one job: thread state across a sequence of applications. It has three arguments: step function, initial state, collection. It returns the final state. There is no hidden complexity, no special syntax, no metadata.

Compare with the alternatives:

- `defprocessor` complects four concerns (Section 5 of Proposal 001).
- `(processor ...)` declaration is redundant information (Hickey's review).
- Convention-only is invisible to the compiler (Beckman's review).
- `fold` adds one control form with clear semantics.

**What is being complected?**

Nothing. `fold` separates the iteration pattern (the fold) from the computation (the step function) from the data (the collection). The step function does not know it is being folded. The collection does not know a fold is consuming it. The fold form connects them.

**Could existing primitives solve it?**

The six primitives are about vector algebra. They do not address iteration. The existing control forms (`for-each`, `map`, `filter`) address stateless iteration. `fold` addresses stateful iteration. It cannot be expressed as a composition of the existing control forms without resorting to mutable closures, which hide the state threading from the compiler and the reader.

A `for-each` with a mutable binding can simulate a fold:

```scheme
(let ((acc init))
  (for-each (lambda (x) (set! acc (f acc x))) items)
  acc)
```

But this uses mutation (`set!`), which the language does not have and should not have. The fold is the pure alternative to mutable iteration state. It is how a language without `set!` expresses stateful iteration.

## 6. Questions for Designers

1. **Is `fold` essential or derivable?** `map` can be derived from `fold`. `filter` can be derived from `fold`. `for-each` can be derived from `fold`. If anything, the question is whether `fold` should replace the others, not whether it should join them. Does the language benefit from having all five, or should `fold` be the single iteration primitive from which the others are derived?

2. **Left fold or right fold?** The proposed `(fold f init items)` is a left fold -- it processes elements left to right, threading the accumulator forward. A right fold processes right to left and enables lazy evaluation. For a language that compiles to Rust and processes finite streams, left fold is the natural choice. Is there a reason to also provide `fold-right`?

3. **Should the result be just the final accumulator, or should it also provide intermediate states?** A `scan` (also called `fold-map` or `reductions`) returns the list of all intermediate accumulator values. This is useful for time series: "the running average at each step." Is `scan` a separate form, or is the base `fold` sufficient?

4. **Does naming `fold` change anything about `journal`?** The journal is a fold whose step function is `observe` and whose state is the accumulator pair. If `fold` is a control form, should the documentation explicitly state that journal is a specialized fold? Or does that create a false expectation that journals can be replaced by raw folds?

5. **Streams or lists?** The proposal says `items` is "a list (or stream)." This is a real question. A list is finite and in memory. A stream is potentially infinite and lazily produced. The enterprise processes a stream of candles -- it does not have them all in memory. Should `fold` accept both? Does the compiler need to distinguish them? Or is this a distinction that belongs at the runtime level, not in the language form?

6. **Is this the right time?** The language has six primitives and four control forms. Adding `fold` brings it to five control forms. The language is young. Is it better to add `fold` now, when the pattern is clear, or to wait until the absence causes a concrete problem that cannot be worked around?
