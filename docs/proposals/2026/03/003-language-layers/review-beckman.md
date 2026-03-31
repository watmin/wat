# Review: Brian Beckman

Verdict: ACCEPT with revisions

---

## What This Proposal Is

An organizational proposal. It names four layers that already exist implicitly: syntax (Layer 0), core (Layer 1), stdlib (Layer 2), userland (Layer 3). It assigns each layer a contract and a boundary rule. It does not add or remove algebraic operations. It does not change what any form computes. It changes where forms are documented and what promises each location makes.

This is good work. The complection it identifies is real. I will address the six questions, then raise two structural concerns.

## The Four Layers Are Correct

The proposal's central observation is that `if` and `journal` are not peers. One is syntax -- domain-agnostic structural scaffolding. The other is algebra -- the reason the language exists. Placing them in distinct layers with distinct contracts makes this visible. A reader who sees `(journal ...)` knows they are in the algebra. A reader who sees `(fold ...)` knows they are in the structural skeleton. This distinction was implicit. Making it explicit costs nothing and clarifies everything.

The four layers form a lattice under dependency: Layer 0 depends on nothing. Layer 1 depends on Layer 0. Layer 2 depends on Layers 0 and 1. Layer 3 depends on all below. Dependencies point down only. This is a partial order. The `require` path prefix (`core/`, `std/`, `mod/`) makes the layer membership syntactically visible. A reader can determine the layer of any form from its import path without reading documentation. This is a genuine improvement over the current state.

## The Category Question

The proposal asks in Section 6 what category the layer model forms. Let me answer directly.

The layers form a tower of algebras, each extending the one below with new generators and new equations. This is not a metaphor. It is the standard construction in universal algebra.

Layer 0 is the free algebra of s-expressions with binding, branching, and iteration. Its generators are `define`, `let`, `if`, `fold`, etc. Its equations are the reduction rules of the lambda calculus (beta-reduction, lexical scoping). This algebra is domain-agnostic. It can express any computable function over its generators.

Layer 1 extends Layer 0 with six new generators: `atom`, `bind`, `bundle`, `cosine`, `journal`, `curve`. These come with equations: `bind` is associative and self-inverse, `bundle` is commutative (approximately), `cosine` is symmetric. Layer 1 is a quotient of the free extension of Layer 0 by these generators, modulo these equations.

Layer 2 extends Layer 1 with derived generators that are *definable* in Layer 1. This is the key distinction. `permute`, `difference`, `negate` are not new generators in the algebraic sense -- they are named compositions of existing generators. They add no new equations that were not already consequences of the Layer 1 equations. Layer 2 is a conservative extension: every theorem about Layer 1 forms remains true in Layer 2.

Layer 3 extends Layer 2 with domain-specific generators (`"momentum"`, `"drawdown"`) that are atoms -- instances of the Layer 1 `atom` generator applied to specific names. Again, no new equations.

The tower is: free algebra, then extension by generators with equations, then two conservative extensions. The functor from each layer to the next is a forgetful functor -- it forgets the additional names. The left adjoint is the free extension. This is standard. The adjunction gives you: stdlib is the most general way to name Layer 1 compositions. Userland is the most general way to name Layer 2 compositions. Nothing surprising here, but it is clean.

## Question 1: Is Layer 0 Correctly Scoped?

Almost. The proposal places `map`, `filter`, `filter-map`, `for-each`, and `fold` all in Layer 0 as compiler-provided syntax. In the 002 review I argued that `map`, `filter`, and `for-each` are derivable from `fold`. That remains true. But I also argued to keep all five because they communicate intent. I hold that position.

However, the scoping test should be: can this form be defined in terms of other Layer 0 forms, and if so, does it still belong in Layer 0? The answer is yes. `map` can be defined in terms of `fold`, but `map` as syntax communicates "structure-preserving transformation" in a way that a fold expression does not. Syntax forms are not minimal generators. They are the forms the compiler recognizes and the human reads. The right criterion for Layer 0 is not algebraic independence but structural intent.

State this criterion explicitly. Layer 0 forms are compiler-recognized structural forms that communicate intent to human readers. They need not be algebraically independent. They must be domain-agnostic.

## Question 2: observe, predict, decay -- Core or Stdlib?

Core. And here is the precise argument.

A primitive in this language is a form whose semantics cannot be expressed as a composition of other forms. `journal` creates a stateful object with hidden accumulators. `observe` mutates those hidden accumulators. `predict` reads the hidden discriminant and computes a cosine. `decay` scales the hidden accumulators.

If `observe`, `predict`, and `decay` were stdlib, they would need to be expressible in terms of the six generators. But they cannot be, because they reach inside the journal's encapsulation boundary. You cannot write `observe` as a composition of `atom`, `bind`, `bundle`, `cosine`, `journal`, and `curve` -- because none of those forms gives you write access to the journal's internal accumulators. The encapsulation is the point. These are not "methods on the journal object" in the OO sense. They are co-generators of the journal algebra. `journal` is the constructor. `observe`, `predict`, `decay` are the destructors (in the coalgebraic sense -- they decompose the state).

The six primitives are really: four algebra generators (`atom`, `bind`, `bundle`, `cosine`) plus a coalgebra (`journal`/`observe`/`predict`/`decay`) plus an evaluator (`curve`). Grouping `journal` with its interface operations in Layer 1 is correct because they form a single coalgebra. Splitting them across layers would be like putting a group's multiplication in one layer and its inverse in another.

The proposal already leans this way. Commit to it.

## Question 3: What Happens to channels.wat?

Split. The proposal's Option 3 is correct.

The channel declaration syntax (`channel`, `publish`, `subscribe`) belongs in Layer 0. Per the 002 resolution, channels are compile-time wiring that compiles to function calls inside a fold. The compiler needs to recognize these forms. They are syntax.

The filter combinators (`gate-open?`, `conviction>`, `always`, `and`, `or`, `not`) are predicates. They are domain-agnostic. They belong in Layer 2 as stdlib. `and`, `or`, `not` are boolean combinators that any language needs. `gate-open?` is a predicate over journals that composes `curve` and a threshold comparison -- it is expressible in terms of core. `conviction>` is a comparator on a prediction field.

The current `std/channels.wat` with its `define-contract`, subscription tables, and runtime guarantees describes something that does not exist in the accepted design. It should be retired as a specification document and replaced by: (a) channel syntax forms in LANGUAGE.md under Layer 0, and (b) filter predicates in `std/predicates.wat` under Layer 2.

One caution: the enterprise example (`enterprise.wat`) uses `publish` and `subscribe` as runtime calls inside lambdas. If channels compile to fold wiring, the publish/subscribe calls in `enterprise.wat` need to be reinterpreted as compile-time declarations, not runtime invocations. The enterprise example will need revision. The proposal should acknowledge this.

## Question 4: Is the core/primitives.wat Cleanup Acceptable?

Yes. The "Derived patterns" and "Additional holon operations" sections in `core/primitives.wat` are the exact source of the complection the proposal identifies. `permute`, `encode-log`, `difference`, `gate` are expressible in terms of the six primitives. They do not belong in the same file. Moving them to `std/` is the right action.

After cleanup, `core/primitives.wat` should contain exactly: `atom`, `bind`, `bundle`, `cosine`, `journal` (with `observe`, `predict`, `decay`), and `curve`. Nine forms. One file. One algebra.

## Question 5: Should Stdlib Have Sub-layers?

No. Not yet.

The proposed decomposition (`std/vectors.wat`, `std/scalars.wat`, `std/memory.wat`, `std/common.wat`, `std/patterns.wat`) is file-level organization, not sub-layering. Files within `std/` may depend on each other. There is no partial order within the layer. This is fine. Do not introduce sub-layers until there is a demonstrated need for one stdlib file to be more stable than another.

The question about `online-subspace` deserving core status is more interesting. The test is: can `online-subspace` be expressed in terms of the six primitives? An online subspace learner (CCIPCA) maintains a set of principal component vectors and updates them incrementally. The update rule involves vector arithmetic that could, in principle, be expressed as sequences of `bind`, `bundle`, and scalar operations. But the implementation requires matrix operations (orthogonalization, eigenvalue tracking) that do not decompose naturally into the VSA primitives. The primitives operate on single vectors. CCIPCA operates on a matrix (the component basis).

This puts `online-subspace` in an uncomfortable position. It is not expressible in terms of the six primitives (which argues for core), but it is also not a single atomic operation with a clean algebraic characterization (which argues against core). My recommendation: leave it in stdlib for now, with a note that it may be promoted. If the language finds that every non-trivial program needs subspaces, and if a clean algebraic characterization emerges (e.g., as a coalgebra analogous to journal), then promote it in a future proposal.

## Question 6: Does mod/ Need More Structure?

No. The language should say nothing about userland organization. This is the application's concern. The only contract is: `mod/` never leaks into `std/` or `core/`. What happens inside `mod/` is the programmer's business.

## Two Structural Concerns

**Concern 1: The layer numbering implies more than it should.**

Calling these Layer 0 through Layer 3 suggests a linear stack. The actual dependency structure is a lattice: Layer 2 depends on both Layer 0 and Layer 1. Layer 3 depends on all three. But the layers are not a total order in any meaningful algebraic sense -- Layer 0 and Layer 1 are independent algebras that Layer 2 combines.

I would prefer names over numbers. "Syntax," "Core," "Stdlib," "Userland" are already the names. The numbers add nothing and create a false impression of linear progression. Drop the numbers. Use the names. The `require` paths already encode the structure: `core/`, `std/`, `mod/`. Layer 0 needs no path because it is the compiler itself.

**Concern 2: The proposal does not state the invariant it preserves.**

Every good organizational refactoring has a preservation theorem: after the change, the same programs compute the same results. The proposal should state explicitly: no existing `.wat` program changes behavior under this reorganization. The only changes are (a) where forms are documented, (b) what `require` paths are used, and (c) what contracts are promised. This is a refactoring in the precise sense -- behavior-preserving restructuring. Saying so makes it reviewable.

## Verdict: ACCEPT with revisions

The four layers are correct. The contracts are correct. The boundary rules are correct. The complection analysis is precise and well-argued. The proposal improves the language without changing it.

Revisions requested:

1. State that `observe`, `predict`, `decay` are core (not an open question) because they form a coalgebra with `journal` that cannot be decomposed into the other primitives.
2. Commit to Option 3 (split) for channels. Acknowledge that `enterprise.wat` needs revision.
3. Drop the layer numbers. Use the names.
4. Add a preservation statement: this is a refactoring. No program changes behavior.
5. State the Layer 0 inclusion criterion explicitly: compiler-recognized, domain-agnostic, intent-communicating. Not algebraic minimality.

The organization is sound. Clean it up and ship it.

---

*Four layers. One lattice. Zero new operations. The algebra is untouched. The language is clearer.*
