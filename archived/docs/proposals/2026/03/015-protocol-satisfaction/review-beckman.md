# Review: Brian Beckman

Verdict: CONDITIONAL

## The question beneath the question

The proposal frames this as a syntax choice: explicit mapping, convention,
or hybrid. That framing hides the algebraic question. Let me reframe it.

A type class instance (what `satisfies` declares) is a **witness** -- a
constructive proof that a type carries the algebra named by the protocol.
The witness must provide *every* operation in the signature. This is not a
design preference. It is a structural requirement. A partial witness is
not a witness. I will make this precise.

## Exhaustive satisfaction is not optional

A protocol is a **presentation of an algebraic theory**: a set of
operation symbols with arities. A type satisfying that protocol provides
an **algebra** -- a concrete interpretation of every operation. An algebra
that interprets only some operations of a theory is not an algebra of
that theory. It is an algebra of a *different* theory (the sub-theory
induced by the operations it does interpret).

In Haskell: a type class instance that omits a method is a compile error
(unless there is a default). In Rust: an `impl Trait` block that omits a
required method is a compile error. In category theory: a functor that
does not map every morphism is not a functor.

The answer to question 2 in the proposal ("is partial satisfaction an
error?") is: **yes, unconditionally**. If the protocol declares three
functions and the `satisfies` maps two, the forge must reject it. Not
warn. Reject. A partial `satisfies` is a type error.

If you want partial satisfaction, the correct construction is protocol
extension: a smaller protocol containing the subset of operations, with
the larger protocol extending it. This preserves the algebraic structure.
Each protocol remains a complete theory, and each `satisfies` remains a
complete witness.

```scheme
(defprotocol steppable
  (step [state input] "Advance by one input."))

(defprotocol indicator
  :extends steppable
  (ready? [state] "Warmed up?")
  (reset [state] "Return to initial state."))
```

A type that provides only `step` satisfies `steppable`, not `indicator`.
The forge checks exhaustively against the declared protocol. No partial
witnesses. No silent omissions.

I note that protocol extension is not yet in the language. That is fine.
The correct response is: **do not add partial satisfaction as a
workaround for missing protocol extension**. If the need arises, propose
extension. Do not weaken the satisfaction contract.

## Option A is the correct construction

Option A (variadic `satisfies` with explicit mapping, one per
struct-protocol pair) is the algebraically clean choice. Here is why:

1. **It is a dictionary.** The `satisfies` block is literally the
   dictionary that witnesses the type class instance. Each `:fn impl-fn`
   entry maps one operation symbol to its interpretation. The dictionary
   is the proof.

2. **It composes.** Multiple protocols on one struct = multiple
   dictionaries. Each `satisfies` block is independent. There is no
   interaction between the indicator dictionary and the serializable
   dictionary for the same struct. This is exactly how Haskell instances
   work: each instance declaration is self-contained. No cross-protocol
   interference.

3. **It maps to Rust.** One `satisfies` block = one `impl Trait for
   Struct` block. The forge generates it. The Rust compiler checks it
   again. Two layers of verification, aligned.

4. **Coherence is trivial.** With one `satisfies` per (struct, protocol)
   pair, there is at most one instance per pair. No orphan instances, no
   overlapping instances, no resolution ambiguity. The coherence problem
   that plagues Haskell (and that Rust solves with orphan rules) does
   not arise because the `satisfies` block sits next to the struct
   definition. The forge can enforce this locality.

## Option B fails the substitution test

Convention-based inference (`sma-step` satisfies `step` because the
prefix matches) is fragile in a precise sense: it **breaks under
renaming**. If I rename `sma-state` to `simple-moving-average`, the
forge must now look for `simple-moving-average-step`. The satisfaction
relationship between a type and its protocol should not depend on the
lexical structure of identifiers. It should depend on an explicit
declaration.

In category theory terms: a natural transformation is defined by its
components, not by naming conventions on the components. The arrow
`alpha_A : F(A) -> G(A)` is identified by its role in the naturality
square, not by the string "alpha" concatenated with "A".

Furthermore, the proposal itself identifies the failure case: `new-sma`
follows `new-{name}`, not `{name}-new`. The convention is already
inconsistent in the existing codebase. A convention that is violated by
its own motivating examples is not a convention. It is a wish.

## Option C inherits Option B's flaw

The hybrid "convention with override" makes the default path implicit and
the exceptional path explicit. This means most satisfaction declarations
carry no information -- the forge must infer everything. The programmer
reads `(satisfies sma-state indicator)` and does not know which functions
are bound without consulting naming rules. The explicit overrides signal
"something unusual here," but the usual case is invisible.

Compare Option A: every satisfaction declaration is a complete,
self-documenting map. You read it and you know the witness. No inference
required. The "boilerplate" is actually **documentation** -- it tells you
exactly which concrete function fulfills each abstract operation. In a
language that values explicitness over magic, this is a feature.

## Multiple protocols on one struct

The proposal asks whether one `satisfies` should list all protocols or
one per protocol. The answer follows from the algebra: **one per
protocol**. Each protocol is an independent theory. Each satisfaction is
an independent witness. Bundling them conflates independent proofs.

```scheme
(satisfies sma-state indicator
  :step    sma-step
  :ready?  sma-ready?
  :reset   sma-reset)

(satisfies sma-state serializable
  :serialize   sma-serialize
  :deserialize sma-deserialize)
```

This is correct. Two independent `impl` blocks in Rust. Two independent
dictionaries. Two independent proofs that `sma-state` carries two
independent algebras. The forge checks each in isolation.

If a future protocol requires that a type satisfy another protocol
(i.e., superclass constraints), that constraint lives in the protocol
declaration (`indicator :extends steppable`), not in the satisfaction
site. The satisfaction site just provides the dictionary. The forge
checks that the prerequisite dictionaries exist.

## The boilerplate concern is real but overstated

The proposal notes that Option A produces boilerplate. Let me count.
The indicator protocol with three functions requires three lines of
mapping per implementing struct. The candle library has approximately
eight indicator types. That is 24 lines of mapping declarations. In a
file that is already 330 lines, 24 lines of explicit witness
declarations is not oppressive. It is informative.

If the boilerplate truly becomes painful (dozens of protocols, hundreds
of types), the correct response is tooling: the forge can *suggest*
the mapping table based on naming convention, the programmer *confirms*
it. The suggestion is implicit. The declaration is explicit. The forge
helps you write the dictionary. It does not write the dictionary for
you and hope it got it right.

## Conditions for approval

1. **Option A, explicit mapping, no convention inference.** Each
   `satisfies` names every operation-to-implementation binding. The
   forge checks exhaustiveness.

2. **Exhaustive satisfaction only.** If the protocol declares N
   functions, the `satisfies` must map all N. Partial satisfaction is
   a forge error, not a warning.

3. **One `satisfies` per (struct, protocol) pair.** Multiple protocols
   = multiple `satisfies` blocks. No bundling.

4. **Duplicate instance rejection.** Two `satisfies` blocks for the
   same (struct, protocol) pair is a forge error. At most one witness
   per pair. Coherence by construction.

5. **Do not add protocol extension in this proposal.** The proposal
   alludes to it indirectly (through the partial satisfaction question).
   Extension is a separate construction with its own algebraic
   consequences (diamond inheritance, superclass constraints). It
   deserves its own proposal. Proposal 015 should settle the
   satisfaction mechanics. Proposal 016 can settle extension.

The algebraic structure is clean: a protocol is a theory, a `satisfies`
is a model of that theory, and the forge is a proof checker. Option A
makes this structure visible in the syntax. Options B and C hide it
behind naming conventions that are already inconsistent. Explicitness
is cheap. Broken inferences are expensive.

-- Brian Beckman
