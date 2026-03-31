# Review: Brian Beckman

Verdict: ACCEPT

---

## Yes. This Is My Argument. And It Is Correct.

The proposal formalizes what I said informally in the 003 review. I want to verify the formalization is precise, because the argument lives or dies on precision.

The claim is: `observe`, `predict`, and `decay` cannot be expressed as compositions of the six forms currently in `core/primitives.wat`. The proposal proves this by exhibiting the obstruction: no core form provides read or write access to the journal's internal accumulators. The proof is by exhaustion over the six forms. `atom` creates vectors. `bind` composes vectors. `bundle` superimposes vectors. `cosine` measures vectors. `journal` constructs opaque state. `curve` reads opaque state. None of these opens the journal for mutation or inspection of its accumulators. Therefore no composition of them can implement `observe` (which writes accumulators), `predict` (which reads the discriminant), or `decay` (which scales accumulators). QED.

This is the correct argument. It is not deep mathematics. It is a straightforward non-expressibility result: the target function requires access that no source term provides. What makes it non-obvious is that the *algorithms* inside these operations decompose into familiar vector algebra. Hickey sees the algorithms and says "compositions." I see the access patterns and say "not expressible." We are both right about different things, and the proposal is precise about which property governs placement: expressibility in the language, not decomposability of the underlying mathematics.

## The Coalgebra Framing

The proposal presents the journal as a coalgebra with:
- A state space (accumulators, discriminant, recalibration counter)
- State transitions from external input (`observe`)
- Projections from state to external output (`predict`, `curve`)
- Endomorphisms on state (`decay`)

This is standard coalgebra. A coalgebra for a functor F is a pair (S, S -> F(S)). Here the functor captures the interface: given a state, you can observe (transition), predict (project), decay (transform), or read the curve (project). The journal constructor is the initial state. The four operations are the structure map's components.

But I want to be more precise than the proposal is. The proposal says "co-generators" loosely. Let me say what this means.

In an algebra, generators are the elements from which all others are built by applying operations. In a coalgebra, co-generators are the *observations* from which all externally visible behavior is determined. If you know what `predict` returns for every input, what `curve` returns, and how `observe` and `decay` transform the state as witnessed through these projections, you know everything about the journal that can be known from outside.

This is exactly the encapsulation property. The journal's internal representation -- how many accumulators, how the discriminant is computed, what the recalibration counter does -- is hidden. The coalgebra interface is the *complete* external characterization. Removing any of the four operations (`observe`, `predict`, `decay`, `curve`) makes the external characterization incomplete: you can no longer distinguish journals that should be distinguishable.

So "co-generators" is not a metaphor. These four operations, together with the constructor, generate all observable behavior of the journal type. They are the minimal complete interface. Splitting them across layers is splitting a coalgebra's structure map across module boundaries. You can do it -- it compiles -- but it violates the algebraic unit.

## The Inconsistency Is Real

The proposal's strongest argument is not the coalgebra theory. It is the inconsistency observation in Section 3.

`curve` is in core. `curve` reads journal internals (the accuracy history). `predict` is in stdlib. `predict` reads journal internals (the discriminant). Both operations project from opaque state to external values. They have identical access characteristics. There is no principled reason for one to be core and the other stdlib.

The only explanation for the current placement is historical accident: `curve` was added to core alongside `journal` because the original design treated prediction quality as part of the primitive's definition, while `observe`/`predict`/`decay` were deferred as "interface" operations. But `curve` IS an interface operation. It is a projection, same as `predict`. If projections from opaque state belong in core (which `curve`'s placement asserts), then all projections from opaque state belong in core.

Hickey's position, taken seriously, would require moving `curve` OUT of core into stdlib. I do not think he wants that. `curve` in core is correct -- it completes the journal's interface. The conclusion is that `predict` and the rest belong there too.

## One Primitive or Six Plus Three?

The proposal frames the result as "six primitives, nine forms" and asks whether this matters. Let me answer directly.

The language has six generators. Four are algebraic: `atom`, `bind`, `bundle`, `cosine`. One is coalgebraic: `journal`. One is evaluative: `curve`. But `curve` is really a fifth component of the journal coalgebra's structure map. So the honest count is: four algebra generators and one coalgebra with five interface forms.

The proposal's framing of "six generators" (four algebra + one coalgebra + one evaluator) is slightly off. `curve` is not a separate generator. It is part of the journal coalgebra. The generator count is five: `atom`, `bind`, `bundle`, `cosine`, and `journal-as-coalgebra`. The coalgebra has five forms (constructor + four co-operations). The total form count is nine.

But I would not fight about this. The important distinction is between generators (things that introduce new algebraic structure) and forms (the syntactic interface to those generators). The language has five generators and nine forms. Or four generators and one compound generator with five forms. Or six generators if you want to count `curve` separately because the curve-fitting algorithm is mathematically distinct from the accumulation/prediction mechanism. These are different ways of slicing the same structure. None of them is wrong. Pick one and be consistent.

My preference: **four algebra primitives and one journal coalgebra**. The coalgebra has five forms. The total is nine forms from five generators. This is the cleanest because it makes the algebraic structure visible in the taxonomy.

## Should It Be One Compound Primitive?

The proposal asks whether the journal should be presented as one compound primitive with nine forms, or six primitives plus three privileged operations. This is a presentation question, not an algebraic one. The algebra does not care how you typeset it.

But presentation matters for the reader. My recommendation: present it as two sections in `core/primitives.wat`.

```scheme
;; Section 1: Vector algebra (four generators)
(atom name) -> Vector
(bind role filler) -> Vector
(bundle facts ...) -> Vector
(cosine a b) -> Float

;; Section 2: Journal coalgebra (one generator, five forms)
(journal name dims recalib-interval) -> Journal
(observe journal thought label weight)
(predict journal thought) -> Prediction
(decay journal rate)
(curve journal resolved) -> (a, b)
```

Two sections. One file. The section headers tell the reader: these are two different algebraic structures that compose. The vector algebra is a commutative (approximate) monoid with a measurement. The journal coalgebra is a stateful learning unit whose internal operations happen to use the vector algebra. Together they form the language's core.

## Question 3: The Precedent

The proposal asks whether "operations on opaque state are core" becomes the general rule. Yes. It must.

If a type is opaque (its internals cannot be accessed from the six -- now nine -- forms), then operations on that type cannot be expressed in terms of those forms. The stdlib contract says: everything in stdlib is expressible in terms of core. Therefore operations on opaque types cannot be in stdlib. Therefore they are core.

This is not a design choice. It is a logical consequence of two prior decisions: (1) the journal is opaque, and (2) stdlib is expressible in terms of core. Given (1) and (2), journal operations are core. If the language introduces another opaque type (say, `online-subspace` with hidden principal components), the same argument applies: its operations must be core.

This is the general rule, and the proposal should state it: **if a type is opaque, its interface operations are core**. This is the opacity invariant. It follows from the stdlib contract.

In the 003 review I recommended leaving `online-subspace` in stdlib because its operations might be expressible in terms of vector primitives. That recommendation stands -- but only because `online-subspace` might not need to be opaque. If it does, the argument applies to it too.

## The Simplicity Analysis Is Sound

The proposal's Section 6 identifies the right complection: "stdlib means derivable from primitives" is complected with "these operations need special access to opaque state." These two ideas contradict. The current design papers over the contradiction by giving `std/journal.wat` privileged access that no other stdlib file has. The proposal resolves the contradiction by moving the operations to where they belong.

I have nothing to add. This is clean.

## Verdict: ACCEPT

The formalization is correct. The coalgebra framing is precise. The inconsistency between `curve` (core) and `predict` (stdlib) is the dispositive argument -- it requires no category theory to understand, only consistency.

Move `observe`, `predict`, and `decay` to core. Retire `std/journal.wat`. Present the core as four algebra generators and one journal coalgebra with five forms. State the opacity invariant as a general rule.

The argument is finished. It was finished in Proposal 003. This proposal merely writes down what was already true.

---

*An opaque type and its interface are one algebraic unit. You cannot split a coalgebra across module boundaries and call the pieces independent. The language knew this when it put `curve` in core. Now it should know it about the rest.*
