# Review: Rich Hickey

Verdict: ACCEPTED with required changes

---

## What This Proposal Actually Is

This is a naming proposal. The layers exist. The hierarchy exists. The proposal names them and draws boundaries. I am generally suspicious of organizational proposals because they tend to add structure without adding clarity. This one adds clarity. The reason: it identifies three specific complections (Section 5) and separates each one. That is the test. Not "is this well-organized?" but "does this separate things that are currently tangled?" It does.

The complection of `if` and `journal` as peers in the same flat list is real. One is syntax, the other is algebra. A reader should not have to infer this from vibes. The complection of `permute` appearing in both `core/primitives.wat` and the stdlib section of `LANGUAGE.md` is real. A form lives in one place. Not two. Not "approximately one." One. The complection of channels existing simultaneously as control forms, stdlib, and a runtime contract system is real and is the worst of the three.

The four layers are correct: syntax, core, stdlib, userland. The boundary rules are correct. The require-path-as-layer-declaration is a good design — the import tells you the layer, which tells you the contract.

## What Must Change

### 1. Remove `observe`, `predict`, `decay` from Layer 1

This is Question 2 in Section 6, and the proposal punts on it. Do not punt.

`journal` is the primitive. It is the thing that exists. `observe`, `predict`, and `decay` are operations on the thing. They are the journal's *interface*, not the journal's *definition*. The mathematical definition of a journal is: two accumulators and a discriminant, recalibrated on interval. That is the constructor. What you do with the journal after construction — feed it observations, ask it for predictions, decay its memory — those are operations built on top of the primitive, not the primitive itself.

The test: can `observe` be defined in terms of the six primitives plus syntax? Yes. `observe` is `bundle` the thought into the appropriate accumulator, weighted. `predict` is `cosine` the thought against the discriminant. `decay` is scalar multiplication of the accumulator. These are derivations from `bind`, `bundle`, `cosine`, and arithmetic. They are stdlib.

But — and this is the critical refinement — they are stdlib that the *compiler* must understand, because the journal is an opaque, encapsulated state container. You cannot implement `observe` in userland because you cannot reach inside the journal to touch its accumulators. This means `observe`, `predict`, and `decay` are stdlib forms with privileged access to the journal primitive's internals.

This is fine. This is what interfaces are. The primitive is `journal`. The interface is `observe`, `predict`, `decay`. The interface lives in `std/journal.wat`, not in `core/primitives.wat`. The compiler knows about both, but the language distinguishes them.

Move them to Layer 2. Create `std/journal.wat`. Document that these forms require compiler support because they operate on opaque state. The primitive count stays at six.

### 2. Retire `std/channels.wat`

This is Question 3 in Section 6, and there are three options listed. Only one is correct.

The current `std/channels.wat` describes a runtime pub/sub system. It has `define-contract`, subscription tables, filter combinators, append-only policies. It is an elaborate specification of something the language does not do. Proposal 002's resolution established that channels are compile-time wiring. The Proposal 002 Beckman review called channels "the anamorphism." The enterprise.wat program uses `publish` as a side-effecting annotation inside `let*` blocks — it does not use subscription tables or filter combinators. The enterprise.wat program is the truth. The channels.wat file is a fiction.

Option A: Retire it. Delete the file. Channels are syntax (Layer 0). Document channel syntax in LANGUAGE.md under Control Forms. The current `(channel name :type schema)`, `(publish channel message)`, `(subscribe channel :filter expr :process fn)` forms in LANGUAGE.md are already the right description. They are compiler directives that wire dataflow inside the fold. They do not need a stdlib file.

Do not do Option B (rewrite as documentation). A `.wat` file that is "documentation of syntax" is a `.wat` file that does not execute. That is a lie. The file extension promises executable specification. If it does not execute, it is not `.wat`, it is `.md`.

Do not do Option C (split). Filter combinators like `gate-open?`, `conviction>`, `always` are not stdlib predicates. They are *part of the channel syntax*. They are compile-time filter expressions that the compiler inlines into the fold body. Pulling them into stdlib implies they are runtime functions you can call anywhere. They are not. They are channel filter syntax. Keep them in the channel syntax definition in LANGUAGE.md.

### 3. Clean up `core/primitives.wat` completely

Question 4 asks whether removing "Derived patterns" and "Additional holon operations" from `core/primitives.wat` is acceptable. Yes. Emphatically. But go further.

The current file has 78 lines. It should have approximately 20. The six primitives, their signatures, one-line comments. No derived patterns. No "Additional holon operations (available, not all used yet)" — that is a wishlist, not a specification. No `gate`, no `permute`, no `encode-log`, no `difference`. All of those move to `std/`.

Additionally: remove `observe`, `predict`, `decay` from this file per point 1 above. The file becomes:

```scheme
;; core/primitives.wat — six primitives
(atom name)
(bind role filler)
(bundle facts ...)
(cosine a b)
(journal name dims recalib)
(curve journal resolved)
```

Six lines of specification. Six primitives. Everything else is somewhere else. That is what "core" means.

## On the Specific Questions

**Question 1: Is Layer 0 correctly scoped?** Yes. `define`, `let`, `if`, `map`, `filter`, `fold`, `require` — these are the language's structural spine. They know nothing about vectors. They are domain-agnostic. They are fixed at language version. The scoping is correct.

Should `map` be sugar for `fold`? Irrelevant. `map` communicates different intent than `fold`. I said this in my Proposal 002 review. Whether the compiler implements `map` as a fold internally is the compiler's business. In the language, they are separate forms because they express separate ideas. Keep all iteration forms in Layer 0.

**Question 5: Is `online-subspace` a seventh primitive?** No. Not yet. Maybe not ever.

The test for core membership is: "Does this form have a mathematical definition that cannot be derived from the existing six?" `online-subspace` is CCIPCA — incremental PCA. It is a matrix factorization algorithm. It does not participate in the VSA algebra. It does not bind, bundle, or measure cosine similarity. It consumes vectors and learns a subspace. It is a *consumer* of the algebra, not a *participant* in it.

The six primitives form a closed algebra: `atom` creates, `bind` composes, `bundle` superimposes, `cosine` measures, `journal` learns direction, `curve` evaluates learning quality. Every primitive either produces vectors, combines vectors, or measures vectors. `online-subspace` learns a *manifold* from vectors. It is a different kind of thing. It belongs in stdlib as a memory structure, alongside `prototype` and `cleanup`.

If a future application demonstrates that subspace learning is as fundamental as directional learning (journal), revisit. But "useful" is not "primitive." The bar for core is mathematical necessity, not practical convenience.

**Question 6: Does `mod/` need more structure?** No. The language should say nothing about userland organization. Userland is the application's business. The moment you prescribe userland structure, you have a framework. Wat is a language, not a framework. Provide the layers. Let the application decide its own shape.

## What I Would Add

The proposal is silent on one thing that matters: **what does `require` actually import?**

When you write `(require std/vectors)`, what comes into scope? All forms defined in that file? A specific export list? Does the file control what it exports, or does the caller see everything?

This matters because the boundary rules depend on it. "Stdlib never imports from userland" is a rule about what `require` can reference. "Userland never leaks into std or core" is a rule about what `require` can reach. These rules are only enforceable if the import mechanism has defined semantics.

The proposal should state: `require` imports all public definitions from the target module. A module's public definitions are all top-level `define` forms. There is no export list. There is no hiding. If you define it at the top level, it is public. If you do not want it public, do not define it at the top level.

This is the simplest possible import semantics. It is also sufficient. The boundary rules are enforced by convention and code review, not by the compiler. The compiler does not need to know that `std/` should not import from `mod/`. The designers need to know that.

## The Simplicity Assessment

The proposal separates four things that were complected. It does not introduce new concepts — it names existing ones. It does not add forms — it moves existing forms to their correct locations. The primitive count remains six. The algebra is untouched.

The one risk is bureaucracy. Four named layers with boundary rules and contracts could become a governance process that slows the language down. The mitigation is already in the proposal: "Stdlib can be extended without a full language proposal." Good. Keep the bar low for stdlib, high for core, and nonexistent for userland. The layers are for clarity, not for gatekeeping.

This is a simple change. Accept it.

---

*The hardest part of a language is not deciding what to put in. It is deciding where things live. This proposal does the hard work of drawing lines. The lines are in the right places. Draw them.*
