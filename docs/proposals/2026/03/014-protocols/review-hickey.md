# Review: Rich Hickey

Verdict: CONDITIONAL

---

## The problem is real

You have a clear pattern: state + step + constructor, recurring across indicators, vocab modules, risk branches, journal consumers. The repetition is visible in `candle.wat` — twelve indicators, all the same shape, no language-level recognition of that sameness. When someone omits the step function and everything compiles, you have a convention masquerading as a contract. That is a real problem worth solving.

## But you are proposing two different things and pretending they are one

The proposal presents dispatch and check-only as two options on a slider. They are not. They are fundamentally different mechanisms with fundamentally different implications.

**Check-only** says: "I want to verify that certain functions exist with certain shapes." That is a linter. It is simple. It is valuable. It does not change how programs run.

**Dispatch** says: "I want to call a function and have the right implementation selected based on the type of the first argument." That is polymorphism. It changes how programs run. It introduces indirection. It requires vtables or match-based dispatch in the generated Rust. It creates a place where the caller no longer knows which code will execute.

These are different proposals. Pick one.

## Which one? Check-only. Here is why.

Wat is a specification language that compiles to Rust. Rust already has traits. Rust already has trait dispatch. Rust's trait system is one of the most sophisticated dispatch mechanisms in any production language — monomorphized, zero-cost, with the borrow checker ensuring safety across every call boundary.

If you add dispatch to wat, you are rebuilding Rust traits in s-expressions. Poorly. You will spend months getting the dispatch semantics right, you will discover edge cases around ownership and borrowing that Clojure never had to think about, and you will end up with something strictly worse than what `rustc` already provides for free.

In Clojure, I designed `defprotocol` with dispatch because Clojure is a runtime language. The protocol IS the dispatch — there is no lower layer to delegate to. Wat is not in that position. Wat has Rust underneath. Use it.

Check-only gives you what you actually need: the guarantee that every indicator provides `step`, that every vocab module provides `eval`, that the shape is enforced at spec time. The Rust trait can be generated from the protocol declaration. The dispatch happens in Rust, where it belongs — monomorphized, zero-cost, with the full power of the type system behind it.

This is the key insight for a specification language: **specify the contract, let the host enforce the mechanism.**

## The `:satisfies` variant needs work

The check-only alternative in the proposal is half-baked. This:

```scheme
(struct sma-state buffer period
  :satisfies indicator
  :step sma-step)
```

This is a mapping table. You are asking the reader to mentally dereference `:step` to `sma-step` to find the implementation. That is indirection without benefit. You have complected the struct declaration with a lookup table for function names.

Simpler: the protocol declares the shape. The struct declares it satisfies the protocol. The forge checks that functions with the right names and arities exist. No mapping table. No indirection. Just naming convention enforced by the tool.

```scheme
(defprotocol indicator
  (step [state input]))

(struct sma-state buffer period
  :satisfies indicator)

;; The forge checks: does (sma-state-step state input) exist?
;; Or: does (step state:sma-state input) exist?
;; The naming convention is the contract.
```

Even simpler: since every indicator in `candle.wat` already follows the naming convention `(TYPE-step state value)`, the protocol could simply declare the convention and the forge walks the codebase checking it. No new syntax on the struct at all. Just:

```scheme
(defprotocol indicator
  (step [state input]))

;; For every struct that declares :satisfies indicator,
;; a function named (STRUCT-NAME-step ...) must exist with arity 2.
```

This is what I would call "documentation with teeth." It is exactly what a specification language needs. Nothing more.

## Inline vs separate: separate

The proposal offers inline implementation:

```scheme
(struct sma-state buffer period
  :implements indicator
  (define (step state value) ...))
```

This complects the data definition with behavior. In Clojure I allowed `defrecord` to inline protocol implementations for convenience, and I have mixed feelings about it. It encourages people to think of structs as objects — bundles of data AND behavior. That is the path to method soup.

Wat already has the right instinct: state is data, computation is function, they are separate. `candle.wat` demonstrates this beautifully. Every struct is just fields. Every step function is a standalone `define`. Do not throw that away for syntactic convenience.

Separate implementation. Always. If it is verbose, that is a feature — it makes you feel the weight of the contract you are fulfilling.

## Does this retire `(field ...)`?

Yes. Retire it. `field` was trying to attach computed values to structs. Protocols subsume that: if you need a derived value, it is a function that a protocol can require. The struct holds data. Functions transform it. The protocol says which functions must exist. Clean.

## Does this complect with the algebra?

No. This is purely structural. Protocols organize functions around types. The algebra (bind, bundle, cosine) transforms vectors. They do not interact. The proposal is careful about this, and I agree with the assessment. Structural forms are orthogonal to the algebras. Keep them that way.

## On return types

The proposal asks whether protocols should specify return types. No. Or rather: not yet. Wat's type annotations are optional documentation. If protocols suddenly require return type specifications while the rest of the language doesn't, you have an inconsistency. Let the protocol check arity and existence. Return types can come later, uniformly, if and when wat grows a type system that earns the right to enforce them.

## What I would change for a specification language compiling to Rust

In Clojure, protocols are a runtime concept because there is no static compilation step where you could check them ahead of time. In wat compiling to Rust, you have an extraordinary opportunity: **the protocol can be a COMPILE-TIME ONLY concept that evaporates completely.**

The protocol exists in the wat layer. The forge checks it. The Rust codegen emits a trait definition. The struct implementations become `impl Trait for Struct`. Then the protocol is gone — it has done its job. There is no protocol object at runtime. No vtable unless Rust needs one. No overhead. The specification language specified, the host language executed.

This is strictly better than what Clojure can do. Use it.

## Summary of conditions

1. **Pick check-only.** Drop dispatch from this proposal entirely. If dispatch is needed later, it is a separate proposal with separate justification.

2. **Simplify the satisfies syntax.** No mapping tables. The protocol declares the shape. The struct declares satisfaction. The forge checks by naming convention. Three independent things, not complected.

3. **Separate implementation only.** No inline protocol implementations in struct declarations. State is data, computation is function. Wat already knows this.

4. **Retire `(field ...)`** in this proposal. One in, one out.

5. **No return types yet.** Arity and existence. The type system earns its way in or it stays out.

6. **Specify the Rust mapping.** The proposal should say explicitly: `defprotocol` generates a Rust trait. `:satisfies` generates `impl Trait`. This is not an implementation detail — it is the design. The protocol is a specification of a trait that the Rust compiler will enforce with its full power.

The idea is sound. The instinct is right. Narrow it to the simple, essential thing and it belongs in the language.
