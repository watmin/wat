# Review: Brian Beckman

Verdict: CONDITIONAL

---

I want to approve this. The instinct is exactly right. But I have conditions, because a core form is forever, and some of the choices here are not yet forced by the algebra.

---

## Answers to the six questions

### 1. Is this a primitive or a convenience?

It is neither. It is a *structural* primitive — which is a third thing.

The two algebras give you operations on vectors and state-threading on journals. Neither one gives you products. You cannot derive `(A, B)` from `bind` — binding two vectors produces a *third vector*, not a pair you can project from. You cannot derive it from `bundle` — bundling is superposition, lossy, non-projectable. You cannot derive it from `let` — `let` binds names in a scope, not names in a value.

So no: there is no composition of existing forms that serves as a record. The proposal is honest about this.

But here is the categorical question the proposal does not quite ask. The two algebras live in a specific world: vectors form a commutative monoid under bundle with bind as a group action, and journals form a coalgebra. Where does the product type live? It lives in the *ambient category* — the category of types and functions that hosts both algebras. Every programming language has this ambient category (it is `Set`, or `Hask`, or whatever you want to call it). Products are the most basic construction in that ambient category.

The proposal says "records don't interact with the vector algebra." This is precisely correct and precisely the point. Products are *structural* — they belong to the ambient category, not to either algebra. They are the scaffolding on which the algebras are mounted.

So: `defrecord` is a primitive of the *ambient structure*, not of either algebra. That is a meaningful distinction. It should be acknowledged in the language spec.

### 2. What is the access syntax?

Dot notation `(. state field)` is the right choice, but for a reason the proposal does not state: it is the *projection morphism*.

In any category with products, the product `A x B` comes equipped with two projections: `pi_1 : A x B -> A` and `pi_2 : A x B -> B`. These are the *universal* way to extract components. The dot syntax `(. state experts)` is `pi_experts(state)`. It is not "field access" in the Java sense — it is the categorical projection. Name it that way and it composes cleanly.

I would accept `(. state field)` or `(field-of state :experts)`. I would reject keyword-first syntax `(:experts state)` because it inverts the morphism direction — the record is the domain, not the codomain.

### 3. Should records be opaque?

Yes. Destructuring is pattern matching, and pattern matching is case analysis, and case analysis belongs to *co*products (sum types), not products. If you allow destructuring, you are implicitly introducing eliminators that break the encapsulation of the product.

The projections are the interface. They are sufficient. If someone needs three fields, they call three projections. This is not inconvenient — it is *correct*. The product is characterized by its projections and nothing else.

If you later want sum types (and you might — `Buy | Sell | Hold` is a coproduct), *then* you introduce pattern matching. Not before.

### 4. Does this change the compilation model?

No, and this is where I am most comfortable. A `defrecord` is a declaration — it says "this product exists and has these projections." The human translator maps it to a Rust struct. A future compiler maps it to a Rust struct. The compilation model is unchanged because the semantics are unchanged: a product type with named projections is the simplest possible data declaration.

The proposal correctly identifies that this does not push wat toward being a "real compiler." It pushes wat toward being a *complete specification language* — one that can name all the things that exist in the program. Right now it cannot name the enterprise state. That is a gap in the specification, not in the execution.

### 5. Is `update` essential?

Yes, but not as a primitive. It is derivable.

Given construction and projection, functional update is:

```scheme
(define (update record field value)
  (record-type
    :field1 (if (= field :field1) value (. record field1))
    :field2 (if (= field :field2) value (. record field2))
    ...))
```

This is mechanical. It should be in stdlib, generated per record type. Do not put it in core. Core has construction and projection. Stdlib has update.

The proposal asks "is the convenience worth the form?" The answer is: yes, but in stdlib, where convenience belongs.

### 6. Where does it live?

This is the hard question, and my answer will surprise you.

**It lives in core, but in a third section.**

The current core has two sections: Vector Algebra (4 generators) and Journal Coalgebra (7 co-generators). `defrecord` is neither. It is the ambient categorical structure — the product construction in the category that *hosts* both algebras.

The primitives file should become:

```
;; ── Vector Algebra (4 generators) ──
;; ── Journal Coalgebra (7 co-generators) ──
;; ── Structural Forms ──
(defrecord name field1 field2 ...)  ; product type
(. record field)                     ; projection
```

Two lines. Construction and projection. That is the entire addition to core.

`update` goes to stdlib. Keyword construction syntax is sugar — it can be in stdlib or it can be part of the `defrecord` expansion. Either way, the core contribution is two lines.

---

## The conditions

I approve this proposal conditional on:

1. **The primitives file gets a third section**, explicitly named as structural (ambient categorical), not algebraic. Do not pretend records are part of either algebra. Do not pretend they are not part of core. They are the product construction in the hosting category. Say so.

2. **`update` moves to stdlib.** Core has construction and projection. Nothing else. The proposal's instinct that update is "derivable" is correct. Follow that instinct.

3. **Records are opaque.** No destructuring, no pattern matching on fields. Projections only. If you want eliminators, propose sum types separately.

4. **The dot syntax `(. record field)` is documented as projection**, not as "field access." The word "projection" carries categorical weight. Use it.

---

## What I admire

The proposal's section 4 — "Records don't interact with the vector algebra" — is the most important sentence in the document. Most language designers would try to make records "work with" the existing system. The proposal correctly identifies that records are *orthogonal*. They carry values through the fold. The algebras transform values within the fold step. These are different jobs.

The fold `(Record, Event) -> Record` is the standard characterization of a Mealy machine. The record is the state object. The algebras are the transition logic. Separating the carrier from the logic is not a design choice — it is the mathematical structure asserting itself.

The 16-parameter heartbeat is not a code smell. It is a *specification gap* — the language cannot name what the program already knows. Closing that gap is exactly what a core form should do.

---

*Brian Beckman, 2026-03-30*
