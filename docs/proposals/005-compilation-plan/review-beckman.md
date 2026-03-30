# Review: Brian Beckman

Verdict: ACCEPT with conditions on Phase 1

---

## The Central Question: Is There a Functor?

The proposal claims a mapping from wat forms to holon-rs types. The compilation tables in Phase 2 lay this out explicitly. Let me verify whether this mapping preserves algebraic structure -- whether it is a functor in any honest sense.

A functor F: C -> D maps objects to objects and morphisms to morphisms, preserving identity and composition. Here C is the category of wat expressions (objects are types like Vector, Journal, Float; morphisms are the nine forms and their compositions). D is the category of Rust types and function calls in holon-rs.

**The vector algebra maps functorially.** This is straightforward. `atom` maps to `VectorManager::get_vector`, producing a `Vector`. `bind` maps to `Primitives::bind`, taking two `Vector` references and returning a `Vector`. `bundle` maps to `Primitives::bundle`. `cosine` maps to `Similarity::cosine`. The types align. Composition is preserved: `(cosine (bind a b) c)` compiles to `Similarity::cosine(&Primitives::bind(&a, &b), &c)`. The Rust type system enforces that you cannot pass a `Journal` where a `Vector` is expected. Identity is preserved: there is no operation that maps to a different operation. This is a faithful functor on the algebra fragment.

**The journal coalgebra maps functorially -- once Phase 1 is done.** Currently the journal coalgebra maps from wat core to application code in a different crate. This is not a functor from the language to its runtime; it is a functor from the language to one particular application. The map is not well-defined for a second application. Phase 1 fixes this by moving the target into holon-rs, making the functor land in the runtime uniformly.

**The stdlib maps functorially.** Each stdlib form maps to exactly one holon-rs call. The types match. Composition is preserved. No surprises here -- the stdlib was designed to mirror holon-rs primitives, so this is almost tautological.

So yes, there is a functor, but it is currently *broken* on the journal fragment. Phase 1 repairs it. This is the strongest argument for the proposal: the compilation mapping should be a functor, it almost is, and one relocation completes it.

## Label Generalization: The Algebraic Content

The proposal generalizes `Outcome::Buy | Sell | Noise` to `Label::A | B | Ignore`. This is Question 1 from the proposal, and it requires careful analysis.

The journal is a binary discriminant. It learns a direction in vector space that separates two classes. The algebraic content is: there exist exactly two accumulators; the discriminant is their normalized difference; prediction is a signed cosine against this discriminant. The sign distinguishes class A from class B. The magnitude is conviction.

This is algebraically correct. The journal's coalgebra structure does not depend on the labels being Buy and Sell. It depends on there being exactly two classes plus an ignore option. The discriminant is `normalize(proto_A - proto_B)`. Positive cosine means "more like A." Negative means "more like B." The labels are names for the sign of a cosine. Any two names work.

**But the proposal should NOT use `Label::A | B | Ignore`.** Here is why.

`A` and `B` are arbitrary names that carry no algebraic meaning. They look like they could be swapped without consequence. But they cannot: the discriminant is `A - B`, not `B - A`. The sign convention is baked into the structure. If an application aliases `A = Sell` and `B = Buy` instead of `A = Buy` and `B = Sell`, every prediction flips. This is a trap.

The honest algebraic names are `Positive` and `Negative`, because they refer to the sign of the cosine against the discriminant. Or `Plus` and `Minus`. Or even keep the trading lab's convention and use `First` and `Second` with a documented sign convention: "the discriminant points from Second toward First." The point is: the names must communicate the asymmetry. `A` and `B` do not. They suggest interchangeability that does not exist.

I recommend:

```rust
pub enum Label { Positive, Negative, Ignore }
```

With documentation: "The discriminant is computed as `normalize(positive_centroid - negative_centroid)`. A positive cosine against the discriminant means the input is more consistent with the Positive class."

This makes the asymmetry visible. Applications alias freely: `const BUY: Label = Label::Positive; const SELL: Label = Label::Negative;` -- and the mapping is self-documenting.

## Curve Placement: The Right Call, but Barely

The proposal asks (Question 2) whether `curve` belongs on Journal in holon-rs or should remain an application pattern. The proposal hedges. I will not hedge.

`curve` is a projection from journal state. It reads the accuracy history -- data that is internal to the journal's operation. In the 004 review I argued that `curve` is part of the coalgebra's structure map, and this argument was accepted in the resolution. So `curve` must move with the journal. Consistency demands it.

However, the fitting algorithm (`accuracy = 0.50 + a * exp(b * conviction)`) is specific. It assumes a particular functional form for the accuracy-conviction relationship. A different domain might find that a linear fit, or a logistic curve, or a piecewise model is more appropriate. The algebraic content of `curve` is "evaluate journal quality as a function of conviction level." The specific exponential form is one implementation of that concept.

My recommendation: `curve` moves to holon-rs as a method on Journal, implementing the exponential fit. This is the coalgebra's evaluation function. If a domain needs a different functional form, that is a different projection -- a different co-operation on the same state. It does not invalidate the default. But `curve` should document that the exponential form is a modeling choice, not an algebraic necessity.

## Phase 2: The Compilation Table Is Necessary

The proposal's Phase 2 is documentation. I have little to say except: do it. The functor I described above is currently in my head and nowhere else. Writing it down is not optional for a language that claims to be a principled compilation target.

On Question 5 (static document vs. embedded doc comments): both. The compilation table is the reference document -- one place, complete, searchable. The doc comments in .wat files are the local hints. They serve different readers. The reference document serves someone asking "what does this language compile to?" The doc comments serve someone reading a .wat file asking "what Rust function is this?"

## Phase 3: The Right Bar for Stdlib Promotion

Question 3 asks about the threshold for unnamed holon-rs operations to earn wat stdlib forms. The proposal suggests "used by two or more unrelated domains." I suggest a stricter test that is also more precise:

**A holon-rs operation earns a wat stdlib form if and only if it is (a) expressible as a finite composition of the nine core forms and (b) useful enough that reimplementing it in every domain would be wasteful.**

Condition (a) is the stdlib contract from Proposal 003. It is non-negotiable. If an operation is NOT expressible from the nine core forms, it is either a new primitive (requiring its own proposal) or an internal implementation detail of holon-rs that wat should not expose.

Condition (b) is pragmatic. `blend` is `bundle` with weights -- probably expressible. `project`/`reject` are compositions of bind, cosine, and arithmetic -- possibly expressible. `grover_amplify` is a quantum-inspired algorithm that may require internal access to vector representation details that the nine forms do not expose. If so, it cannot be stdlib; it must remain an unnamed utility.

The audit should verify expressibility first, utility second.

## Question 4: Memory Module Scope

Should Journal live in `holon-rs/src/memory/` alongside OnlineSubspace and Engram?

Yes. All three are stateful learning primitives. They share the property of being opaque containers with co-algebraic interfaces: you feed them data (state transitions), they produce assessments (projections), and they can be aged or snapshotted. The memory module is the right home. Giving Journal its own top-level module would suggest it is architecturally different from OnlineSubspace, but it is not. They are both coalgebras over the vector algebra. They are peers.

The memory module's doc comment should be updated to reflect its organizing principle: "stateful learning primitives with opaque internal state and coalgebraic interfaces."

## One Concern: The Diagnostic Fields

The proposal says `decode_discriminant`, `last_cos_raw`, and `last_disc_strength` do not move. Good. These are observation instruments -- they break the opacity for debugging purposes. They should not be part of the runtime's public API.

But the current implementation (`holon-lab-trading/src/journal.rs`) has `pub buy` and `pub sell` -- the accumulators are publicly accessible fields. If Journal moves to holon-rs, these fields must become private. The entire argument for the coalgebra -- the opacity that makes observe/predict/decay co-generators rather than compositions -- depends on the accumulators being hidden. Public accumulators would make observe expressible as stdlib (just `journal.buy.add_weighted(...)`) and would destroy the algebraic justification for journal being core.

**Condition for acceptance:** When Journal moves to holon-rs, the accumulators must be private. The trading lab accesses them through the five forms plus a `discriminant()` accessor for analysis. If the trading lab currently depends on direct accumulator access beyond what observe/predict/decay/curve provide, those access patterns must be expressed through new accessors, not through pub fields.

This is not a nitpick. It is the load-bearing property. The entire Proposal 004 argument rests on opacity. A `pub buy: Accumulator` field makes that argument false.

## Summary

The compilation plan is sound. The functor from wat forms to holon-rs types exists and is well-defined modulo the journal gap that Phase 1 closes. The label generalization is algebraically correct but should use names that reflect the sign asymmetry (`Positive`/`Negative`, not `A`/`B`). Phase 2 is necessary and overdue. Phase 3 needs the expressibility test from the stdlib contract.

One hard condition: make the accumulators private when Journal moves to holon-rs. Without this, the opacity that justifies the coalgebra framing is a fiction, and the entire 004 argument unravels.

---

*A functor that is broken on one object is not a functor. Fix the journal's home and the compilation mapping becomes honest. But while you are at it, make the opacity real. A coalgebra with public state is just a struct with methods.*
