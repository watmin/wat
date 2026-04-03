# Review: Brian Beckman

Verdict: APPROVED

---

## The Shape of the Proposal

This is a structural annotation. It does not extend the algebra. It does not introduce new types, new control flow, or new state management. It adds two words -- `pmap` and `pfor-each` -- that grant the runtime a permission it did not previously have. The semantics are identical to `map` and `for-each`. The difference is a promise from the programmer: these elements are independent.

I want to be precise about what "independent" means here, because the proposal uses the word informally and the formalization matters.

## Independence Is a Structural Property

Two computations are independent when they commute. If `f(a)` and `f(b)` can be evaluated in either order -- or simultaneously -- and the observable result is identical, then `f` over `{a, b}` is independent. For `pmap`, this is guaranteed by purity: a pure function has no side effects, so the order of evaluation is unobservable. For `pfor-each`, it is guaranteed by disjointness: each invocation mutates a different root object, so the mutations commute.

This is the right distinction. Purity and disjoint mutation are the two conditions under which reordering is safe. The proposal names both. It does not confuse them. It assigns the stronger condition (purity) to the form that returns values (`pmap`) and the weaker condition (disjointness) to the form that performs effects (`pfor-each`). This is correct.

Now, the category theory. A natural transformation between functors is a family of morphisms, one per object, satisfying a coherence condition. `map f` is a natural transformation from the list functor to itself. `pmap f` is the same natural transformation. Naturality does not depend on evaluation order. The naturality square commutes whether you compute the components left-to-right, right-to-left, or in parallel. This is why `pmap` is safe as a structural annotation: the algebraic content -- the naturality -- is unchanged. The annotation lives below the algebra, in the operational semantics that the algebra cannot observe.

## The Five Questions

**Question 1: Is `pmap` the right form, or should parallelism live in the compilation guide?**

In the language. Here is the argument.

The compilation guide describes how forms map to Rust. It is a property of the compiler, not the program. If parallelism lives only in the compilation guide, then the programmer cannot express "these are independent." The compiler must infer independence. Independence inference is, in general, undecidable -- it requires proving that a function has no side effects or that mutations are disjoint, which is equivalent to solving the frame problem.

The programmer knows. The programmer wrote six observers that each own their own journal. The programmer knows these do not share state. This knowledge should be expressible in the program, not hidden in a compiler optimization pass that may or may not fire.

`pmap` is the programmer telling the compiler: I guarantee independence. The compiler trusts this guarantee and parallelizes. If the guarantee is wrong, the program has a race condition -- the same consequence as lying to any other type system. The ward can check the easy cases (no `set!` in the lambda). The hard cases (disjoint ownership in `pfor-each`) require the programmer's assertion. This is the right division of responsibility.

**Question 2: Should `pfor-each` exist separately?**

Yes. And the argument is exactly the one I made in the 002 review about keeping `map`, `filter`, and `for-each` alongside `fold`.

`pmap` says: independent, pure, results collected. `pfor-each` says: independent, side-effecting, results discarded. These are different semantic declarations. A reader who sees `pmap` knows: no mutations, output list same length as input. A reader who sees `pfor-each` knows: mutations on disjoint state, no output. Collapsing them into "pmap with discarded results" hides the mutation. The reader must trace the lambda to discover that `pmap` is actually performing side effects and throwing away dummy return values. That is hostile.

Keep both. They are not redundant. They communicate different contracts.

**Question 3: Is the safety contract expressible in the language or a ward concern?**

Both, but differently.

The `pmap` contract -- purity -- is checkable syntactically. A lambda that contains no `set!`, `push!`, `inc!`, or calls to known-impure functions is pure. The ward can verify this by inspecting the AST. This should be a compile-time check, not a runtime assertion. It belongs in the language's static semantics.

The `pfor-each` contract -- disjoint mutation -- is harder. The proposal's example is instructive: `(pfor-each (lambda (obs) (decay (:journal obs) rate)) observers)`. Each invocation mutates `(:journal obs)`, and each `obs` is a different element of the list. Disjointness follows from the fact that field access on distinct objects yields distinct references. This is checkable if the language has an ownership model (each element owns its own fields). It is not checkable in general -- aliasing makes it undecidable.

My recommendation: make the `pmap` purity check a ward (static, mandatory). Make the `pfor-each` disjointness check a ward where possible (distinct list elements, field access through the lambda parameter). Where the ward cannot verify, require the programmer's explicit assertion. Document the unsafe cases.

**Question 4: Should `pmap` guarantee result order?**

Yes. Emphatically.

`pmap` is semantically identical to `map`. `map` preserves order. Therefore `pmap` preserves order. If the runtime evaluates elements out of order, it must reassemble the results in input order before returning.

This is not a performance concern. It is a correctness concern. The pattern `(fold f init (pmap g xs))` depends on the fold receiving elements in input order. The fold is a left fold. Left folds are order-sensitive when the step function is not commutative. Most interesting step functions are not commutative. If `pmap` returned results in arbitrary order, `(fold f init (pmap g xs))` would produce nondeterministic results. That would defeat the entire purpose.

Rayon's `par_iter().map().collect()` preserves order. Rust's `thread::scope` with indexed results preserves order. There is no performance reason to abandon order, and every correctness reason to preserve it.

**Question 5: Does `(fold f init (pmap g xs))` compose?**

This is the question I have been waiting for since the fold proposal.

Yes. And the composition is beautiful. Let me spell out why.

A fold is a catamorphism. A map is a natural transformation. The composition "natural transformation followed by catamorphism" is itself a catamorphism -- this is fold-map fusion, one of the oldest theorems in program calculation. `(fold f init (map g xs))` equals `(fold (lambda (acc x) (f acc (g x))) init xs)`. The fused version does one pass. The unfused version does two.

With `pmap`, the composition `(fold f init (pmap g xs))` has a natural operational reading: compute all `(g x)` in parallel, then reduce sequentially. This is the MapReduce pattern. It is not an accident. MapReduce is exactly fold-map fusion over a parallel map. Google did not invent this. They named it. The algebra has known it for decades.

The important point: the fold does NOT parallelize. The fold is sequential. This is correct. The fold carries state forward. It cannot be parallelized without knowing that the step function is associative (which enables a parallel reduction tree). The proposal explicitly declines to add `pfold`. This is the right decision. Parallel reduction is a separate concern requiring a separate contract (associativity of the step function), and it should be a separate proposal if it is ever needed.

The idiom is: parallel map, sequential reduce. `pmap` for the map. `fold` for the reduce. The composition is well-typed, order-preserving, and semantically identical to the sequential version. The parallelism is invisible to the algebra. The fold cannot observe whether its input was computed sequentially or in parallel. This is the definition of a correct structural annotation.

## The No-`pfold` Decision

I want to commend this explicitly. The temptation to add `pfold` is real. "If we have `pmap`, why not `pfold`?" Because the contracts are different.

`pmap` requires independence of elements. This is a property of the function and the data.

A parallel fold would require associativity of the step function. This is a property of the algebra. `bundle` is associative (approximately). `bind` is associative. But most step functions in the enterprise -- the heartbeat, the journal update, the risk evaluation -- are not associative. They depend on order. They carry state that each step modifies.

Offering `pfold` would be an invitation to misuse. The programmer sees `pfold` and thinks "my fold will go faster." But unless the step function is associative, the result is wrong. And verifying associativity is not a syntactic check -- it is a mathematical property that no ward can verify in general.

`pmap` is safe because purity is syntactically checkable. `pfold` would be unsafe because associativity is not. The asymmetry is fundamental. The proposal recognizes it. Good.

## One Observation

The proposal lists eight sites where `pmap`/`pfor-each` would apply. Six observers, five risk branches, multiple desks, multiple field projections. All of these have the same structure: a small collection (5-8 elements) of independent computations, each moderately expensive (vector encoding, cosine projection, subspace residual).

This is the sweet spot for `pmap`. The collection is small enough that thread-pool overhead is amortized over the per-element cost. If the elements were cheap (simple field access) or the collection were large (10,000 elements), the calculus would be different -- cheap elements would be dominated by scheduling overhead, and large collections would benefit from chunked parallelism or SIMD rather than thread-per-element.

The proposal does not discuss granularity, and it should not. Granularity is a compilation concern. The compiler decides whether to actually parallelize a given `pmap` based on element count and estimated cost. The language says "you may." The compiler decides "you should." This separation is correct. But the documentation should note that `pmap` is a permission, not a command, and that the compiler may evaluate small or cheap `pmap` calls sequentially.

## Verdict: APPROVED

The proposal adds two structural forms that grant a permission without changing a result. The algebra is untouched. The fold composes. The safety contracts are precise and differentiated (purity for `pmap`, disjointness for `pfor-each`). The decision to exclude `pfold` is correct and well-reasoned. The result ordering guarantee is essential and should be stated as a requirement, not left as an open question.

One minor addition to the specification:

1. State explicitly that `pmap` preserves input order in the output. This is non-negotiable.
2. Note in the documentation that `pmap` is a permission, not a directive. The runtime may evaluate sequentially if parallelism would not improve throughput.
3. The `pmap` purity ward should be mandatory at compile time. The `pfor-each` disjointness ward should be best-effort with an explicit programmer assertion for cases the ward cannot verify.

The forms are simple. The semantics are clean. The composition with `fold` is the MapReduce pattern, which has been studied for decades and is known to be correct. There is nothing here to object to.

---

*Parallel map is not a feature. It is the recognition that independence is information, and information belongs in the program.*
