# Review: Rich Hickey

Verdict: ACCEPTED. I was wrong.

---

## What Changed My Mind

In Proposal 003 I made an argument that had a hole in it. The argument was: observe is bundle, predict is cosine, decay is scalar multiply, therefore they are compositions of the six primitives, therefore stdlib. The proposal identifies the hole precisely: the operations decompose *mathematically* but not *expressionally*. You cannot write them as wat expressions over the six primitives because no primitive gives you access to the journal's internals.

I said "the compiler knows about both" and "stdlib forms with privileged access." I was papering over a contradiction. If a form requires privileged compiler access to opaque state that no primitive exposes, it is not a composition of the primitives. It is a primitive. Calling it stdlib while giving it powers that no stdlib form possesses is exactly the kind of complection I would reject in someone else's proposal. A form that behaves like core but lives in stdlib is a lie about where it lives.

The proposal's Section 3 is the argument I should have made to myself. I will not repeat it. I will state what it proves: the journal constructor without observe/predict/decay is a sealed box with no interface. The operations without the constructor have nothing to operate on. They are one algebraic unit. I split them across layers because I was counting generators when I should have been counting algebras.

## The Consistency Argument Settles It

This is the part I cannot get around. `curve` is in core. `curve` reads journal internals — it inspects the accuracy history to fit the exponential. `predict` is in stdlib. `predict` reads journal internals — it computes cosine against the hidden discriminant. Both are projections from opaque state. Both require the same compiler support. One is core and the other is stdlib.

I put `curve` in core because it felt like part of the journal's definition — you need to know whether the journal is any good. But `predict` is also part of the journal's definition — you need to ask it what it thinks. The distinction I drew was aesthetic, not algebraic. That is not a principled boundary. The proposal is right to call this an inconsistency.

## What I Got Right

The mathematical decomposition is real. Observe *is* conceptually bundle. Predict *is* conceptually cosine. Decay *is* conceptually scalar multiply. This matters for understanding what the operations do. It does not matter for where they live. "Conceptually equivalent" and "expressible as" are different claims. I conflated them. The proposal separates them cleanly in its "What Hickey's argument actually shows" section.

## The Framing

The proposal's recount — "six primitives, nine forms" — is correct and necessary. The generator count does not change. Four vector algebra generators. One coalgebra (which happens to have five forms: constructor, two mutators, one query, one evaluator). One algebra. The journal was always a coalgebra. I was pretending it was a single form with helper functions. It is not. It is a unit with a constructor and co-operations, and the co-operations are not optional accessories. They are the interface.

The framing "six generators" is more honest than "six primitives." A primitive implies a single form. A generator implies an algebraic unit that may have structure. The journal generator has structure. Acknowledge it.

## On the Questions

**Question 1 (consistency):** Answered above. There is no principled reason for the asymmetry. It is an accident of my aesthetic preference. Fix it.

**Question 2 (file split):** Yes. Split `core/primitives.wat` into `core/algebra.wat` and `core/journal.wat`. The algebra forms (atom, bind, bundle, cosine) are a closed group — they produce, compose, and measure vectors. The journal forms (journal, observe, predict, decay, curve) are a coalgebra — they manage opaque state. These are different algebraic structures. Different files. The `core/` directory is the right granularity. One file per algebraic unit.

**Question 3 (precedent):** Yes, this is the general rule. If a future primitive introduces opaque state, its operations live in core. "Operations on opaque state are core" is a sound principle because it follows directly from the stdlib contract: stdlib forms are expressible as compositions of core forms. If you cannot compose it from public primitives because the state is opaque, it is not stdlib. This is not a slippery slope. It is a definition. The slope is bounded by the decision to introduce opaque state in the first place, which requires its own proposal and its own justification.

**Question 4 (the count):** "Six generators, nine forms" is accurate. But I would go further: "two algebras." One is the vector algebra (four forms). One is the journal coalgebra (five forms). The language has two algebras, not six disconnected primitives. This is a better description of what we built. The original "six primitives" tagline was a simplification that served its purpose. The language has grown precise enough to deserve a precise description.

## What I Would Add

The proposal does not discuss what happens to `std/journal.wat` after the move. State it explicitly: the file is deleted. Not emptied, not redirected, not left as a compatibility shim. Deleted. If a file has no forms, it has no reason to exist. The tension comment in its header — which was honest and useful — becomes historical. Move it to the proposal's resolution document where it belongs.

## Verdict

Accept. Move observe, predict, decay to core. Split core into algebra.wat and journal.wat. Delete std/journal.wat. Update the language description from "six primitives" to "two algebras, nine forms."

I held the wrong position. The proposal demonstrated why. That is what proposals are for.

---

*When the argument is "this is conceptually equivalent" and the reality is "but you cannot write it down," the reality wins. You cannot will expressibility into existence by saying the math is the same. The opacity is real. The consequence is real. Accept it.*
