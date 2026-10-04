# Review: Rich Hickey

Verdict: CONDITIONAL

---

## The Right Instinct, The Wrong Boundary

The proposal correctly identifies that `map` over independent computations is leaving performance on the table. It correctly identifies that the parallelism is a *permission*, not a *mechanism*. It correctly avoids `pfold`. It correctly preserves the heartbeat as sequential. These are all good instincts.

But the proposal puts the permission in the wrong place.

## The Problem With `pmap` as a Language Form

`pmap` is not a new concept. It is `map` with a metadata annotation: "these elements are independent." The proposal says this explicitly: "semantically identical to `map`." If the semantics are identical, then the form is not carrying meaning. It is carrying an optimization hint.

Optimization hints do not belong in the language. They belong in the compilation guide. They belong in the thing that transforms wat into Rust. The language says *what*. The compiler decides *how*. This is the same argument I made about the entry point in Proposal 001: deployment facts go in deployment configuration, not in the grammar.

Consider the trajectory. Today you add `pmap` and `pfor-each`. Tomorrow someone wants `pfilter`. Then `pmap` with a chunk size. Then `pmap` with a thread-pool affinity. Then `pmap` with a priority. Each one is "just one more parameter." Each one is reasonable in isolation. Each one drags the language toward being a runtime configuration DSL. The language should not know about threads. The language should not know about rayon. The language should know about *values and transformations*.

## What `map` Already Says

`map` says: "apply this function to each element, collect the results." It does NOT say: "apply them left to right, one at a time, waiting for each to finish before starting the next." That is what sequential implementations do, but it is not what `map` *means*. The mathematical `map` is a functor. It maps morphisms. It says nothing about evaluation order.

The proposal claims that `map` "cannot express these are independent." But `map` over a pure function IS independent by definition. If the function is pure, the elements do not depend on each other. The information is already there. It is in the purity, not in the name of the form.

The compiler can see this. If the mapped lambda contains no `set!`, no `push!`, no `inc!`, no mutation — it is pure. The compiler can parallelize it. No annotation needed. The ward system you already have can verify purity. The compilation guide can say: "pure `map` over collections of size > 1 may be parallelized." Done. No new form.

## The `pfor-each` Problem Is Worse

`pfor-each` claims "each element's mutations must be independent." The proposal says the compiler verifies disjointness through ownership. But this is asking the language to express a Rust concept. Disjoint mutation is `&mut` semantics. It is a Rust borrow-checker concern. The wat language does not have a borrow checker. It should not grow one.

`for-each` is already the problematic form. It exists for side effects. Side effects are where reasoning breaks down. Adding "parallel side effects with a disjointness contract" does not make reasoning easier. It makes it harder. The contract is "each invocation touches disjoint state" — but the language has no mechanism to enforce this. The proposal defers enforcement to "the compiler or ward." If the ward can check it, the ward can check it on `for-each` and the compiler can parallelize without a new form.

The six `for-each` calls in the proposal — decay, resolve, learn — all operate on different observer instances. The compiler can see this. Each lambda takes an element from the collection and calls methods on that element. The element is the root. The mutations are on the element. The compiler knows this because the borrow checker knows this. You do not need to tell it twice.

## The Fold Composition Is Fine — And Irrelevant

The proposal asks: "Does `(fold f init (pmap g xs))` compose?" Yes. But this is the wrong question. `(fold f init (map g xs))` also composes, and if `g` is pure and the compiler parallelizes `map`, you get the same result without a new form. The composition argument proves that the semantics are right. It does not prove that the syntax is needed.

## Answer the Questions

**Question 1: Language or compilation guide?** Compilation guide. The parallelism is a compiler concern. The language expresses independence through purity (which the ward system already checks). The compiler exploits it.

**Question 2: Should `pfor-each` exist separately?** No. Neither `pfor-each` nor `pmap` should exist.

**Question 3: Language or ward concern?** Ward concern. The purity check for `map` and the disjointness check for `for-each` are structural analyses. They are what wards do. They are not what language forms do.

**Question 4: Result order?** `map` preserves order. A compiler that parallelizes `map` must preserve order. This is not negotiable. `map` is a functor. Functors preserve structure.

**Question 5: Fold composition?** No concerns, but irrelevant to the question of whether `pmap` should exist.

## What You Should Do Instead

1. **Add a compilation directive**, not a language form. The compilation guide says: "When the mapped function is pure (verified by ward), the compiler may parallelize `map` using `rayon::par_iter`. When `for-each` operates on disjoint elements (each lambda invocation's mutations root at the collection element), the compiler may parallelize using `rayon::par_iter_mut`."

2. **Let the ward verify the preconditions.** Purity analysis for `map`. Disjoint-mutation analysis for `for-each`. These are static analyses. They run at compile time. The programmer writes `map`. The ward checks purity. The compiler emits `par_iter`. The programmer never writes `pmap`.

3. **If you must have programmer control**, use an annotation, not a new form:

```scheme
;; Annotation — not a form. Metadata on the call site.
#:parallel
(map (lambda (obs) (encode-thought ...)) observers)
```

This is still not ideal — I would prefer the compiler to figure it out — but it is better than a new form because it does not add to the grammar. It is metadata. It can be ignored by a sequential runtime. It does not change the semantics. And most importantly, it does not multiply the iteration forms. You do not need `pfilter`, `pfold`, `psort`. You have one annotation that applies to any form where the compiler can verify the precondition.

4. **Do not grow the language.** The iteration forms are `map`, `for-each`, `filter`, `filter-map`, `fold`, `count`. Six forms. Each one says what it does. None of them say how fast to do it. Keep it that way.

## The Deeper Issue

The proposal quotes me: "the heartbeat is your greatest asset." It is. The heartbeat is sequential. The parallelism within a heartbeat step is an optimization. Optimizations are real. Performance matters. I am not saying "don't parallelize." I am saying "don't put the parallelism in the language."

Clojure has `pmap`. I added it. It is one of the things I would reconsider. The problem with `pmap` is that it creates a split world: every `map` call site becomes a decision point — "should this be `map` or `pmap`?" The programmer must now think about parallelism at every map call. This is a tax on every reader of every function. The compiler should bear this cost, not the programmer.

Wat is a specification language. It specifies what the enterprise does. It does not specify how the runtime executes it. The compilation guide bridges that gap. Parallelism lives in the bridge, not in the specification.

---

*The best parallel code is code that does not know it is parallel. The function is pure. The compiler sees it. The runtime exploits it. The programmer writes `map`.*
