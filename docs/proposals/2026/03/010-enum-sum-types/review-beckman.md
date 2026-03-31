# Review: Brian Beckman

Verdict: **Accept.** This is not optional. A category with products and no coproducts is half a category.

## Answers to the four questions

### 1. Simple vs tagged — one form, two modes

One form. The coproduct construction in any category with an initial object gives you both: a finite coproduct of terminal objects (your "simple" keywords) and a finite coproduct of arbitrary objects (your "tagged" variants). These are the same construction. `(enum direction :long :short)` is just the degenerate case where each summand carries no data — the injection *is* the value. Making two separate forms would be like having `struct-with-one-field` and `struct-with-many-fields`. Don't split what the algebra unifies.

### 2. Where does it live — `core/structural.wat`, next to `struct`

Yes, and the file's own preamble already says why. Line 4: "The ambient category's product construction." The coproduct is the dual. They live together or the structural layer is incomplete. I would go further: the file header should be updated to say "product and coproduct constructions" once this lands.

### 3. Exhaustiveness — the spec declares, the compiler enforces

The spec MUST declare exhaustiveness. That is the entire point of closing the set. If `(enum direction :long :short)` does not mean "and nothing else," it is just a comment. The forge and the Rust compiler both enforce — but the *authority* is the wat declaration. A `match` that omits a variant is a spec violation, not merely a compiler warning. The spec is upstream of the compiler. Let the spec be the source of truth.

### 4. Naming — keywords, not atoms

Keywords. Your own proposal answers this correctly in the last sentence: "Enum variants are identities, not geometric objects." Atoms allocate vectors. Keywords are structural tags. An enum variant is a discriminant — it selects an injection into the coproduct. It has no business occupying a dimension in the vector space. `:long` is a label. `(atom "long")` is a direction in 10,000-dimensional space. These are categorically different things. Use keywords.

## One additional note

The proposal correctly states that enums do not interact with the vector algebra. I want to strengthen this: they *must not*. If someone writes `(bind (atom "direction") :long)`, the `:long` is not a vector and the bind should be a type error at the spec level. The structural layer and the algebraic layer are orthogonal by design. Enum keeps them orthogonal. This is a feature.
