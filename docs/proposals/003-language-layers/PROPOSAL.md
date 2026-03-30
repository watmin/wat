# Proposal 003: Language Layers

Status: PROPOSED

Scope: **core** — clarifying the structure of the wat language itself.

---

## 1. The Current State

The wat language has accumulated forms across several files and documents. What exists today:

**`core/primitives.wat`** declares six VSA primitives: `atom`, `bind`, `bundle`, `cosine`, `journal`, `curve`. It also lists derived operations (`permute`, `encode-log`, `difference`, `attend`, `prototype`, etc.) under a "Derived patterns" heading.

**`LANGUAGE.md`** documents three categories:
- **Core Forms (corelib):** the six primitives.
- **Standard Library (stdlib):** scalar encoders, vector operations, memory (online-subspace), gate, noise-floor.
- **Control Forms:** `define`, `let`, `let*`, `if`, `when`, `match`, `for-each`, `map`, `filter`, `filter-map`, `fold`, `channel`, `publish`, `subscribe`.

**`std/common.wat`** defines shared atoms (predicates, directions, temporal, logical).

**`std/channels.wat`** defines a pub/sub contract with `define-contract`, `channel`, `publish`, `subscribe`, and filter combinators.

**`examples/enterprise.wat`** is a complete program that uses all of the above.

What works: the six primitives are clear and stable. The enterprise program composes cleanly. The `fold` acceptance (Proposal 002) established that control forms are a legitimate category distinct from the six primitives.

## 2. The Problem

The language has layers, but they are implicit and inconsistent. A reader cannot determine where a form lives or what its status is without reading multiple files and inferring from context.

**2a. Control forms have no home.** `define`, `let`, `if`, `map`, `filter`, `fold` — these are documented in `LANGUAGE.md` but do not exist as `.wat` files. They are not in `core/primitives.wat`. They are not in `std/`. They appear in the grammar reference as a flat list. Are they deeper than core? Are they the compiler itself? The language does not say.

**2b. The core/std boundary is blurred.** `core/primitives.wat` lists `permute`, `encode-log`, and `difference` as "Derived patterns" below the six primitives. `LANGUAGE.md` lists these same operations under "Standard Library (stdlib)." The same form appears to live in two layers depending on which document you read. A consumer cannot tell: is `permute` a core primitive or a stdlib convenience?

**2c. Channels have an uncertain status.** `std/channels.wat` defines `channel`, `publish`, `subscribe` with a rich contract system (`define-contract`, filter combinators like `gate-open?`, `conviction>`, `always`). But `LANGUAGE.md` lists `channel`, `publish`, and `subscribe` as control forms — the same category as `if` and `let`. Meanwhile, Proposal 002's resolution established that channels are compile-time wiring that compiles to function calls inside a fold. If channels are compile-time sugar over fold, they are not a runtime contract system — and `std/channels.wat` as written describes a runtime contract system.

**2d. No explicit layer model.** The `require` system imports from paths (`core/primitives`, `std/common`, `std/channels`, `mod/oscillators`) but the language does not define what these path prefixes mean. What is `core/` vs `std/` vs `mod/`? What is the contract for each? Can userland override stdlib? Can stdlib extend core? The directory structure implies a hierarchy but the language does not declare one.

## 3. The Proposed Change

Define four explicit layers. Each layer has a name, a location, a contract, and a boundary rule.

### Layer 0: Syntax

**What lives here:** The s-expression reader. The grammar from `LANGUAGE.md` (atom, number, string, list, comment). The binding forms (`define`, `let`, `let*`). The conditional forms (`if`, `when`, `match`). The iteration forms (`map`, `filter`, `filter-map`, `for-each`, `fold`). The module form (`require`). Type annotations.

**Where it lives:** In the compiler. No `.wat` file. These forms are the language itself — the substrate that all other layers are written in.

**Contract:** Syntax forms are domain-agnostic. They know nothing about vectors, journals, or cognition. They are the structural skeleton: naming, branching, iteration, composition. A program that uses only Layer 0 forms computes but does not think.

**Boundary rule:** Syntax cannot be extended by any other layer. These forms are fixed at language version. Adding a new syntax form (as `fold` was added in Proposal 002) requires a language proposal.

### Layer 1: Core (`core/`)

**What lives here:** The six VSA primitives and nothing else.

```scheme
;; core/primitives.wat — the complete contents
(atom name)
(bind role filler)
(bundle facts ...)
(cosine a b)
(journal name dims recalib)
(curve journal resolved)
```

Plus the journal operations that are part of the journal primitive's interface: `observe`, `predict`, `decay`.

**Where it lives:** `core/primitives.wat`. One file.

**Contract:** Core forms are the algebra. They are the reason the language exists. Every core form has a mathematical definition (binding = element-wise multiplication, bundling = element-wise majority, cosine = normalized dot product, journal = online discriminant learning, curve = logistic fit). Core forms cannot be implemented in terms of each other or in terms of stdlib — they are axiomatic.

**Boundary rule:** Core can only be extended by language proposal with designer review. The bar is: "Does this form have a mathematical definition that cannot be derived from the existing six?" Convenience is not sufficient.

### Layer 2: Standard Library (`std/`)

**What lives here:** Derived operations built from core primitives. Everything currently listed under "Standard Library (stdlib)" in `LANGUAGE.md`:

```scheme
;; std/vectors.wat — derived vector operations
(permute vector shift)          ; element rotation
(difference before after)       ; structural change
(negate superposition component)
(amplify superposition component strength)
(prototype vectors threshold)
(cleanup noisy codebook)
(attend query memory strength mode)
(coherence vectors)
(similarity-profile a b)

;; std/scalars.wat — scalar encoding
(encode-linear value scale)
(encode-log value)
(encode-circular value period)

;; std/memory.wat — memory structures
(online-subspace dims k)
(update subspace vector)
(residual subspace vector)
(threshold subspace)

;; std/common.wat — shared atoms (unchanged)
;; std/patterns.wat — derived patterns
(gate journal curve threshold)
(noise-floor dims)
(sweet-spot dims)
```

**Where it lives:** `std/*.wat`. Multiple files organized by concern.

**Contract:** Every stdlib form can be defined in terms of core primitives and syntax. `permute` is an element rotation of a vector. `difference` is `bundle(negate(before), after)`. `encode-log` maps a scalar to a vector via the core `bind` and `atom` operations. If a form cannot be expressed in terms of core, it does not belong in stdlib — it belongs in core (and must pass the core bar).

**Boundary rule:** Stdlib can be extended without a full language proposal, but new forms must demonstrate they are (a) domain-agnostic and (b) expressible in terms of core. Stdlib never imports from userland.

**What happens to channels:** `channel`, `publish`, and `subscribe` move OUT of `std/channels.wat` in their current form. Per Proposal 002's resolution, channels are compile-time wiring that compiles to function calls inside a fold. This means:

- As syntax sugar for wiring fold steps, they belong in **Layer 0 (Syntax)** — they are compiler directives, not stdlib functions.
- The current `std/channels.wat` with its `define-contract`, filter combinators, and subscription tables describes a runtime pub/sub system that does not match the accepted design. It needs to be rewritten or retired.

This is an open question for designers (see Section 6).

### Layer 3: Userland (`mod/`, application code)

**What lives here:** Domain-specific vocabularies, application architectures, programs.

```scheme
;; Application-specific vocabulary modules
(require mod/oscillators)       ; momentum atoms and encoders
(require mod/segments)          ; structure atoms and encoders

;; Application programs
;; examples/enterprise.wat
```

**Where it lives:** `mod/` for vocabulary modules, `examples/` for programs, or in the application's own repository.

**Contract:** Userland may use all lower layers. Userland defines domain-specific atoms, encoders, and architectures. Userland does not extend the language — it uses it.

**Boundary rule:** Userland never leaks into std or core. If a userland pattern proves universal, it may be promoted to stdlib via proposal. Domain-specific atoms (`"momentum"`, `"drawdown"`) never enter stdlib.

### The `require` semantics

The `require` form resolves by layer:

```scheme
(require core/primitives)    ; Layer 1 — always available
(require std/common)         ; Layer 2 — standard library
(require std/scalars)        ; Layer 2
(require mod/oscillators)    ; Layer 3 — application vocabulary
```

The path prefix (`core/`, `std/`, `mod/`) is the layer declaration. A reader seeing `(require std/vectors)` knows immediately: this is a derived operation, expressible in terms of core, domain-agnostic. A reader seeing `(require mod/oscillators)` knows: this is application-specific vocabulary.

## 4. The Algebraic Question

**Does this compose with the existing monoid (bundle/bind)?**

This proposal does not add algebraic operations. It organizes existing ones. The monoid is unchanged. Bundle and bind remain in Layer 1 (Core). Derived operations that use them (`difference`, `negate`, `amplify`) are in Layer 2 (Stdlib). The algebra is untouched.

**Does it compose with the state monad (journal)?**

Journal remains in Layer 1. Its interface operations (`observe`, `predict`, `decay`) remain in Layer 1. The fold that drives journals is in Layer 0 (Syntax). This is consistent: the catamorphism (fold) is structural; the accumulation (journal) is algebraic.

**Does it introduce a new algebraic structure?**

No. This is a organizational proposal, not an algebraic one. It names a hierarchy that already exists implicitly.

## 5. The Simplicity Question

**Is this simple or easy?**

Simple. It separates four concerns that are currently complected:
- Syntax (the language's structural forms) from primitives (the language's algebraic forms)
- Core (axiomatic, mathematically defined) from stdlib (derived, expressible in terms of core)
- Stdlib (domain-agnostic) from userland (domain-specific)
- Compiler directives (Layer 0) from runtime operations (Layers 1-2)

**What is being complected today?**

1. Control forms and primitives share the same flat list in `LANGUAGE.md`. `if` and `journal` appear to be peers. They are not — `if` is syntax, `journal` is algebra.
2. Core and stdlib share content. `permute` appears in both `core/primitives.wat` and the stdlib section of `LANGUAGE.md`.
3. Channels appear simultaneously as control forms (Layer 0), stdlib (Layer 2), and a runtime contract system (`std/channels.wat`). Three layers at once.

**Could existing structure solve it?**

The directory structure (`core/`, `std/`, `examples/`) already gestures at this hierarchy. But without explicit contracts and boundary rules, the structure is suggestive rather than definitive. The proposal makes implicit structure explicit.

## 6. Questions for Designers

1. **Is Layer 0 (Syntax) correctly scoped?** The proposal places `define`, `let`, `if`, `map`, `filter`, `fold`, and `require` in the compiler as fixed syntax forms. Is this the right boundary? Should any of these be expressible in wat itself (e.g., `map` as sugar for `fold`)? Or should all iteration forms be compiler-provided?

2. **Should `observe`, `predict`, and `decay` stay in Layer 1 or move to Layer 2?** They are the journal's interface — but they could be seen as derived operations on the journal primitive. If `journal` is the primitive and `observe`/`predict`/`decay` are its methods, are the methods also primitive? Or is only the constructor primitive, with the methods being stdlib?

3. **What happens to `std/channels.wat`?** Three options:
   - **Retire it.** Channels are syntax (Layer 0 compiler directives) per the Proposal 002 resolution. The current file describes a runtime system that no longer matches the design. Delete it and define channel syntax in LANGUAGE.md.
   - **Rewrite it.** Keep `std/channels.wat` but rewrite it to describe the compile-time wiring contract — what a channel declaration means, how `subscribe` compiles to a fold step, what the filter expressions compile to. The file becomes documentation of the syntax, not a runtime contract.
   - **Split it.** Channel declaration syntax goes to Layer 0. Filter combinators (`gate-open?`, `conviction>`, `always`, `and`, `or`, `not`) move to Layer 2 as stdlib predicates that happen to be useful in channel filters but are not channel-specific.

4. **Is the `core/primitives.wat` cleanup acceptable?** The proposal requires removing the "Derived patterns" and "Additional holon operations" sections from `core/primitives.wat`, leaving only the six primitives and journal interface operations. Everything else moves to `std/`. Does this match the designers' intent for what "core" means?

5. **Should Layer 2 (Stdlib) have sub-layers?** The proposal suggests `std/vectors.wat`, `std/scalars.wat`, `std/memory.wat`, `std/common.wat`, `std/patterns.wat`. Is this the right decomposition? Is `memory` (online-subspace) truly stdlib, or is it closer to a seventh primitive that deserves core status?

6. **Does `mod/` need more structure?** The proposal treats all userland as flat under `mod/`. But applications may have their own layering (vocabulary modules vs. architecture modules vs. programs). Should the language say anything about userland organization, or is that the application's concern?
