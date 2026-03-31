# Review: Brian Beckman

Verdict: CONDITIONAL

Conditional on: Q2 resolved as typed fields, Q5 resolved as flat projection only. The rest I approve as stated with my preferred choices below.

---

## Preamble

You have a language that compiles to Rust. You have a category whose objects are wat types and whose morphisms are wat functions, and a faithful functor F from that category into Rust's type system. The word "faithful" is doing all the work: distinct morphisms in wat must map to distinct morphisms in Rust. If two different wat programs compile to the same Rust, the functor is not faithful and your language has ambiguity. Keep that in mind for every answer below.

---

## Question 1: `defstruct`, `struct`, or `record`?

**Categorical perspective.** A named product type is a product object in your category. The form name is the *introduction rule* for that product. Whatever you call it, the semantics are identical: you are declaring a labeled tuple with projections. The name is syntactic, not semantic.

**Which composes?** `struct`. Here is why. You have a functor F : Wat -> Rust. The introduction rule for products in Rust is the keyword `struct`. If your introduction rule in Wat is also `struct`, then F acts as the identity on that particular syntactic element. The functor becomes *transparent* at the declaration site. `defstruct` adds a `def` prefix that F must strip. `record` requires F to rename entirely. Neither is wrong, but both add a translation step that `struct` avoids.

**Which will the compiler thank you for?** `struct`. The compiler writer pattern-matches on form names. `struct` maps one-to-one to Rust's `struct`. No renaming table, no heritage disambiguation. The compiler is a functor; make it as close to the identity as the syntax permits.

The objection that this "breaks Lisp convention" is irrelevant. The proposal itself notes that wat is not a general-purpose Lisp. You already have `match`, which is not `defmatch`. You have `let`, not `deflet`. Top-level `def*` is a convention for binding names in an environment; `struct` is a declaration that creates a *type*, not a binding. The distinction is real. Lean into it.

**My choice: `struct`.**

---

## Question 2: Typed fields or untyped?

**Categorical perspective.** A product in a typed category has typed projections. The projection pi_1 : A x B -> A carries the type A in its signature. If your product declaration omits the types of its projections, you have a product in a *unityped* category -- everything is the same type, or the types are implicit and reconstructed later. That is fine for a dynamically typed Lisp. It is not fine for a language that compiles to Rust, where every struct field has a mandatory type.

**Which composes?** Typed fields. The functor F must produce Rust structs with typed fields. If wat declarations are untyped, F must *infer* those types from usage sites. Type inference is a whole-program analysis. Whole-program analysis means your functor is not *local* -- it cannot translate one form at a time. Locality of translation is composability of compilation. If you want the compiler to be a compositional functor (translate each form independently, assemble the results), the types must be present at the declaration site.

Your LANGUAGE.md already has the syntax for optional type annotations: `[name : Type]`. Use it. The proposal shows it. The question answers itself.

**Which will the compiler thank you for?** Typed fields, unambiguously. A compiler that can emit a Rust struct from a single form, without consulting any other form, is a compiler that someone can actually write and maintain. The annotation syntax is already in the language. Use it here.

**My choice: Typed fields, using the existing bracket annotation syntax.**

```scheme
(struct trade-pnl
  [gross-return : Float]
  [net-return : Float]
  [position-usd : Float])
```

If you want gradual typing -- untyped during prototyping, typed for compilation -- that is fine, but the compilation target must be the typed form. Make the types optional for the human, mandatory for the compiler pass.

---

## Question 3: Named or positional construction?

**Categorical perspective.** Construction is the *universal morphism* into the product. In a category with named projections, the universal morphism is determined by its action on each named component. That is named construction. Positional construction relies on an *ordering* of the projections, which is extra structure the product does not inherently have. Products in category theory are defined up to isomorphism -- the components are identified by their projections, not by position.

**Which composes?** Named construction. If you reorder fields in the declaration, positional construction silently breaks. Named construction is *invariant under permutation of the declaration*. That is exactly the property a categorical product should have: the components are identified by name (projection morphism), not by position.

**Which will the compiler thank you for?** Named. The compiler can emit Rust's `EnterpriseState { experts: e, generalist: g, ... }` by direct transcription. Positional construction would require the compiler to look up the declaration, resolve positions, then emit named Rust -- another non-local step.

**My choice: Named construction only.** Do not offer positional as an alternative. Two ways to do the same thing is not a feature; it is an ambiguity the compiler must resolve and the reader must guess at.

```scheme
(enterprise-state
  :experts experts
  :generalist generalist
  :treasury treasury)
```

---

## Question 4: Keyword or bare symbol in `update`?

**Categorical perspective.** `update` is a morphism that takes a product, a projection name, and a value, and returns a new product. The projection name is *data about the type*, not a runtime value. In a typed setting, it is an element of the label set of the product. Keywords (`:field`) are syntactically distinct from value symbols (`field`). This distinction encodes the difference between "which component" (a label) and "what value" (a term).

**Which composes?** Keywords. If `field` is a bare symbol, the compiler must determine from context whether it names a projection or a variable. That is another whole-program question. If `:field` is always a projection label and `field` is always a value, the compiler can parse the `update` form locally. Local parsing composes. Contextual disambiguation does not.

**Which will the compiler thank you for?** Keywords. The colon is a syntactic tag that says "I am a label, not a value." The compiler does not need a symbol table to parse an `update` form. It sees `:experts`, knows it is a field name, and emits `EnterpriseState { experts: value, ..state }`. Done.

**My choice: Keywords.** `(update state :field value)`.

This is also consistent with named construction (Q3), where the field names are keywords. One convention, used everywhere.

---

## Question 5: Nested access?

**Categorical perspective.** Nested access `(.. state treasury balance)` is *composition of projections*: pi_balance . pi_treasury. Projection composition is just function composition. Category theory has no special syntax for it because it needs none -- composition is the ambient operation. A special form `..` introduces a new syntactic category for something that is already expressible as composition of existing forms.

**Which composes?** The flat form `(. (. state treasury) balance)`. It uses one operation -- projection -- composed with itself. No new syntax. No new compiler form. The general composition mechanism of the language (nesting of s-expressions) already handles it.

**Which will the compiler thank you for?** Flat projection. The `..` form requires the compiler to handle a variadic chain of field names, look up each intermediate type, and emit a chain of Rust field accesses. The nested `(. (. state treasury) balance)` is two instances of the *same* compiler rule, composed by the language's own nesting. The compiler handles one case. The language handles composition. That is the entire point of having a compositional language.

If nested access is common enough to be noisy, the answer is `let` bindings:

```scheme
(let ((t (. state treasury)))
  (. t balance))
```

This is what every compositional language does. Do not add syntax for what let-binding already solves.

**My choice: No `..` form.** Flat `(. record field)` only. Nesting is already composition.

---

## Summary

| Question | My choice | Principle |
|----------|-----------|-----------|
| 1. Form name | `struct` | Functor transparency -- minimize the distance between source and target |
| 2. Typed fields | Yes, with existing `[name : Type]` syntax | Local translation -- the compiler is a compositional functor |
| 3. Construction | Named only | Permutation invariance -- products are identified by projections, not positions |
| 4. Update syntax | Keywords (`:field`) | Syntactic distinction -- labels are not values |
| 5. Nested access | No special form | Composition of projections is just composition -- do not add syntax for what nesting already provides |

## Conditions for approval

1. **Typed fields must be the compilation-facing form.** You may allow untyped declarations during design (as documentation-only wat), but the compiler must reject untyped struct declarations. A functor into a typed target category requires typed source objects.

2. **No `..` form.** If it appears later as sugar, it must be a macro that expands to nested `(. ...)`, not a primitive the compiler handles.

Meet these two conditions and I approve without reservation. The rest of the choices in this proposal are sound. The heartbeat example in section 6 is exactly right -- four parameters instead of sixteen is the structural improvement that products exist to provide.

---

*Composability over power. Always.*
