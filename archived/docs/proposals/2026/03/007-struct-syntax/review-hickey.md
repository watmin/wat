# Review: Rich Hickey

Verdict: CONDITIONAL

Conditionally approved. Two of the five questions have clear answers. Two have answers that require discipline. One is a trap you should not walk into.

---

## Question 1: `defstruct`, `struct`, or `record`?

**`struct`.** No prefix.

The `def` prefix in Lisp means "define a binding in the current namespace." `defn` defines a function. `def` defines a value. `defrecord` defines a record type. The `def` is doing work — it says "I am creating a named thing at the top level."

But that work is *already done by the form's position*. A top-level form in wat that declares a named product type is obviously a definition. The `def` prefix is ceremony. It complects the act of naming (which is universal) with a Lisp convention (which is parochial).

`struct` is the right word because it is *Rust's* word, and wat compiles to Rust. When someone reads `(struct enterprise-state ...)` they know exactly what they will find in the compiled output. When they read `(defstruct enterprise-state ...)` they think of Common Lisp's `defstruct`, which auto-generates constructors, predicates, copiers, and slot accessors. Wat does none of that. Using `defstruct` creates a false expectation. Using `struct` creates a true one.

`record` is the ML/Haskell word. It is a fine word. But it is not the word that appears in the compiled output. Wat's transparency principle — that the specification should be readable alongside the implementation — demands that the specification use the same vocabulary as the target. The word is `struct`.

What you will regret: `defstruct`. Every new reader will ask "what does the `def` buy me that `struct` doesn't?" The answer is nothing. That is the definition of accidental complexity.

---

## Question 2: Typed fields or untyped?

**Untyped.** But let me be precise about what I mean.

The proposal offers two forms:

```scheme
(struct trade-pnl gross-return net-return position-usd)

(struct trade-pnl
  [gross-return : Float]
  [net-return : Float]
  [position-usd : Float])
```

The typed form introduces square brackets *as a new reader form*. Your own constraint says "no new reader forms." This is not a small thing. Every new piece of reader syntax is a tax on every future reader and every future tool. Square brackets are not in your grammar. Adding them for type annotations means you have complected *declaration* with *documentation*.

Wat already has optional type annotations on function parameters using the same bracket syntax (LANGUAGE.md line 94). So the brackets are not truly new — but they are being *repurposed*. In function signatures, brackets delimit parameters. In struct declarations, they would delimit fields. Same syntax, different semantics. That is complecting.

The types in Rust structs are mandatory. The compiler enforces them. Wat is a specification language — its types are documentation, as LANGUAGE.md explicitly states. The Rust compiler will enforce the types regardless of what wat says. So the type annotations in the wat form are *redundant with the compilation target*. Redundant information is information that can become inconsistent.

Keep fields as bare symbols. If you need type documentation, a comment serves:

```scheme
(struct trade-pnl
  gross-return    ; Float
  net-return      ; Float
  position-usd)   ; Float
```

What you will regret: mandatory type annotations. They will drift from the Rust types. You will build tooling to keep them in sync. That tooling will have bugs. You will have created a second source of truth for information that already has an authoritative source.

What you will not regret: bare symbols. They can never be wrong.

---

## Question 3: Named or positional construction?

**Named.** This is not close.

Positional construction complects the meaning of a value with its position in a list. If someone reorders the fields in the struct declaration, every positional construction site silently changes meaning. This is *place-oriented programming* — the very thing I have spent decades arguing against.

Named construction is *value-oriented*. Each field is named at the point of use. The declaration can be reordered without breaking anything. A reader can understand the construction without consulting the declaration. The form is self-describing.

```scheme
(enterprise-state
  :experts experts
  :generalist generalist
  :treasury treasury)
```

This maps directly to Rust's `EnterpriseState { experts, generalist, treasury }`. It is transparent. It is safe. It is simple — not easy, simple. There is nothing interleaved that doesn't need to be there.

Positional construction is *easy*. It is fewer characters. But it complects field identity with field position. You will pay for that ease every time someone adds a field to a struct and forgets to update a construction site. The compiler will not catch it if the types happen to align.

What you will regret: positional construction. It is a false economy. You save keystrokes today and lose hours debugging silent field misalignment tomorrow.

---

## Question 4: Keyword or bare symbol in `update`?

**Keyword.** `(update state :field value)`.

This is a question about whether the syntax distinguishes the *name of a field* from the *value being set*. Consider:

```scheme
(update state field value)
```

Is `field` a symbol that will be evaluated to get a field name? Or is it a literal field name? In Lisp, bare symbols in function-call position are evaluated. If `update` is a special form that treats its second argument as a literal, that is invisible to the reader. You have complected evaluation semantics with positional convention.

Keywords solve this cleanly. `:field` is never evaluated. It is a literal name. The reader knows immediately that `:experts` refers to the `experts` field, not to a variable called `experts` whose value might be a field name.

More importantly, keywords create visual symmetry with construction:

```scheme
;; Construction
(enterprise-state :experts new-experts :treasury treasury)

;; Update
(update state :experts new-experts)
```

Same pattern. Keywords mark field names. Bare symbols mark values. The two are never confused. This is what keywords are *for*.

What you will regret: bare symbols. You will write `(update state experts new-value)` and someone will read `experts` as a variable reference. The ambiguity is permanent and costs you on every read.

---

## Question 5: Nested access — `(. (. state treasury) balance)` or `(.. state treasury balance)`?

**Neither.** Do not add `..` and do not encourage nesting.

`(.. state treasury balance)` is a convenience form that complects *two separate projections* into a single expression. It hides the intermediate step. If `(. state treasury)` returns something that doesn't have a `balance` field, the error will point at a `..` form and the programmer must mentally decompose it to find which projection failed.

But `(. (. state treasury) balance)` is fine. It is two projections composed. It is explicit. It is ugly. That ugliness is a *feature* — it tells the programmer "you are reaching two levels deep into a structure, and maybe you should ask whether the inner structure should be providing this value directly."

Deep access chains are a code smell in any language. `a.b.c.d` in Rust is a sign that your abstractions are leaking. Adding `..` to wat would make deep access *easy* without making it *simple*. It would remove the syntactic pressure that currently encourages flat interfaces.

Do not add a form. The existing `(. ...)` composes. Composition is Lisp's answer to everything. Trust it.

What you will regret: `..`. It is a special case. Special cases are not special enough to break the rules. You will add `..` for two levels, then someone will want three, then someone will want to mix projection with update, and you will have a path expression sublanguage growing inside your s-expressions. Kill it in the cradle.

---

## Summary

| Question | Answer | Principle |
|----------|--------|-----------|
| 1. Form name | `struct` | Use the target's word. No false heritage. |
| 2. Typed fields | Untyped | One source of truth. Redundancy drifts. |
| 3. Construction | Named | Values, not places. |
| 4. Update syntax | Keyword `:field` | Distinguish names from values. |
| 5. Nested access | No new form | Composition over convenience. |

## The condition

Rename `defrecord` to `struct` in `core/structural.wat` and in proposal 006's resolution. The language should not carry two names for the same concept. If proposal 006 said `defrecord` and proposal 007 says `struct`, someone reading both will think they are different things. They are the same thing. Use one name. Use the right name.

The right name is `struct`, because it is what the thing *is* in the language it compiles to, and it carries no baggage from a language it does not compile to.
