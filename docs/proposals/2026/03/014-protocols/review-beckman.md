# Review: Brian Beckman

Verdict: CONDITIONAL

## What categorical construction is this?

Let me be precise. What you are proposing is a **type class** in the
Haskell/Wadler-Blott sense, not a natural transformation. A natural
transformation would relate two functors; you are relating types to
shared signatures. The proposal says "these types share behavior" --
that is exactly what a type class says. Clojure calls them protocols,
Haskell calls them type classes, Rust calls them traits. The
categorical object behind all three is the same: a **presentation of
an algebraic theory** -- a signature (operation names and arities) plus
equational laws (which you have not stated, but I will come back to
that).

The dispatch variant adds **dictionary passing** -- the vtable is the
dictionary. The check-only variant is a **constraint** on types at the
meta-level, with no runtime witness. Both are legitimate constructions.
They are not the same construction, and the choice between them has
algebraic consequences that the proposal does not fully reckon with.

## Does it live in the ambient category alongside struct/enum?

Yes, and it should. Your `structural.wat` declares two constructions in
the ambient category of program types: products (struct) and coproducts
(enum). A protocol/type-class is a third construction: a **signature
in the theory of types**. It does not compete with struct or enum. It
classifies them. A struct is a product. An enum is a coproduct. A
protocol is a **predicate on types** -- it selects those types that
carry a given algebra.

This is the right place for it. The structural layer already names the
shapes that values inhabit. Protocols name the shapes that types
inhabit. Same layer, one level up.

## Does it preserve the algebra's independence?

This is the question that matters most, and the proposal gets it right
in principle: "Does not change the algebra. Protocols are structural,
orthogonal to bind/bundle/cosine." Good. The six primitives (atom, bind,
bundle, cosine, journal, curve) must remain untouched. A protocol is a
statement about program organization, not about vector geometry.

But I want to see this enforced, not just claimed. The proposal should
state explicitly: **no protocol may appear in a corelib signature**. The
corelib is the algebra. Protocols are meta-structure over the types that
*use* the algebra. If someone writes `(defprotocol encodable (encode
[self] -> Vector))`, that protocol lives in stdlib or userland, never in
corelib. The algebra does not know about protocols. Protocols know about
the algebra. This asymmetry must be a rule, not a convention.

## Dispatch vs check-only: the algebraic consequences

The proposal presents these as a taste question. They are not. They are
categorically distinct.

**Check-only** (`:satisfies`) is a **logical assertion**. It says: "I
claim this type carries an implementation of this signature." The forge
verifies the claim at spec-validation time. No runtime artifact is
generated. The caller must know the concrete type. This is a
**refinement type** -- it narrows the set of valid programs without
changing the operational semantics.

**Dispatch** (`(step state value)` resolving to the right implementation)
is an **existential type**. The caller says: "I have some type that
satisfies `indicator`. I do not know which one." The vtable/dictionary
is the **witness** that the existential is inhabited. This adds a new
kind of abstraction to wat -- the ability to write functions polymorphic
over the protocol. That is a phase transition in the language's
expressiveness.

The candle library does not need dispatch. `tick-indicators` calls
`sma-step`, `ema-step`, `wilder-step` by name. It knows every concrete
type. Check-only is sufficient and honest.

But the proposal lists four protocol-shaped patterns, and at least two
of them want dispatch:

- **Vocab modules**: the enterprise loops over N vocab modules calling
  `(eval module candles)`. Today that loop is hand-written with a match
  or a list of concrete calls. With dispatch, it becomes `(map (lambda
  (m) (eval m candles)) modules)`. That is cleaner and it grows without
  editing the loop.
- **Journal consumers**: `(observe journal thought label weight)` is
  already dispatched through the journal coalgebra. Adding observers
  that share a protocol interface would want the same.

My recommendation: **start with check-only. Do not add dispatch in this
proposal.** Dispatch is the right thing eventually, but it requires
answering questions this proposal has not asked:

1. What is the representation of the dictionary at the Rust level?
   `dyn Trait`? Enum dispatch? Monomorphization?
2. Can a type satisfy multiple protocols? (Yes, obviously, but then
   you need to specify the coherence rules.)
3. Can protocols extend other protocols? (Not proposed, but someone
   will ask within a month.)

Check-only gives you 80% of the value (enforced conventions, the forge
catches missing implementations) with 0% of the dispatch machinery.
Ship it. Dispatch is proposal 015.

## How does this compose with the journal coalgebra?

The journal is an opaque coalgebra: `(journal, observe, predict, decay,
resolve, curve)`. It already has the shape of a protocol -- a set of
operations on an opaque state. But it is a *primitive*, not a
user-defined protocol. It lives in corelib.

The question is: does `defprotocol` retroactively describe the journal?
No, and it should not. The journal is the *only* coalgebra. It is not
one of many things satisfying a "learner" protocol. It is THE learning
primitive. Wrapping it in a protocol would suggest there are alternative
implementations. There are not. The journal is axiomatic.

What protocols *do* compose with is the **consumer side** of the
journal. Every observer calls `observe` and `predict`. The observer
protocol would formalize that pattern:

```scheme
(defprotocol observer
  (perceive [self candles bank] "Produce thoughts from market data.")
  (opinion  [self thought]      "Predict from a thought."))
```

This is the right use. The protocol classifies the *users* of the
coalgebra, not the coalgebra itself.

## Does this retire (field ...)?

Yes, and I agree with the proposal's reasoning. `(field struct-name
field-name computation)` was an attempt to attach derived behavior to
product types. Protocols are the correct abstraction for "types that
carry behavior." The `field` form conflates data (the struct) with
derived computation (the field body). Protocols separate them: the
struct holds data, the protocol signature names the computation, the
implementation provides it.

Retire `field` from LANGUAGE.md and stdlib when this proposal is
accepted. Do it in the same commit. Do not leave two mechanisms for
attaching behavior to types.

## Conditions for approval

1. **Check-only first.** Remove the dispatch variant from this proposal.
   File dispatch as a separate, future proposal. The check-only variant
   (`:satisfies` with named function bindings) is the right starting
   point.

2. **State the corelib boundary rule.** No protocol may be declared in
   or required by corelib. Protocols live in structural.wat or above.
   The algebra does not depend on protocols. This must be written into
   the proposal, not left implicit.

3. **Separate `implement` blocks only.** Do not allow inline
   `:implements` on struct declarations. The struct declares data. The
   `implement` block declares behavior. Separating them preserves the
   product-type semantics of struct -- a struct is a product, full stop.
   Inline `:implements` turns struct into a class declaration. That is
   a category error.

4. **Equational laws.** The proposal says a protocol is "one or more
   function signatures." A signature without laws is half a theory. For
   the indicator protocol, the law is: `(step state input)` returns
   `(new-state, output)` where `new-state` has the same type as `state`.
   The fold contract. You do not need a full equational logic, but the
   protocol should carry at least a docstring-level statement of the
   laws. The forge can check structural properties (return arity, type
   preservation) even if it cannot check semantic ones.

5. **Retire `field` in the same proposal.** Do not leave two mechanisms.

If these five conditions are met, this is a clean, conservative addition
to the structural layer. It names a pattern that already exists in every
wat file I have read. It does not infect the algebra. It gives the forge
something new to check. It retires a weaker mechanism.

The categorical genealogy is sound: type classes in a language that
already has products and coproducts. The three constructions (product,
coproduct, type class) are the basic furniture of any typed programming
language's ambient category. You have been missing the third one. Now
you will have it.

-- Brian Beckman
