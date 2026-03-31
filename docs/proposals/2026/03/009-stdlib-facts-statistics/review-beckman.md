# Review: Brian Beckman

Verdict: **Accept both. Two files.**

## Answers

### 1. Do fact constructors belong in stdlib?

Yes. These are the canonical injection morphisms from the domain of names into the vector algebra. Every application that uses `bind` and `atom` to encode named knowledge will write exactly these four patterns. Putting them in stdlib is the same move as putting `map` in a list library — you could inline the recursion every time, but you'd be insane to.

The structure `bind(atom("at"), bind(atom(indicator), atom(zone)))` is a *convention*, and conventions that aren't named become conventions that drift. Name them. Ship them.

### 2. Do statistics belong in stdlib?

Yes. `mean`, `variance`, `stddev`, `skewness` — these are the thermometer readings you take before you hand data to the algebra. They produce Float, not Vector. They sit below the algebra, which is exactly where stdlib helpers should sit when they're universal.

The only question is whether `skewness` earns its place with one usage. I'd keep it. It's three lines, it composes from the others, and any streaming system that cares about distribution shape will want it. The cost of carrying it is zero. The cost of someone reimplementing it wrong is nonzero.

### 3. Should `(bundle)` with no args be the lazy identity?

No. The identity element of a monoid over a fixed-dimensional vector space has a definite size. A lazy identity that adopts dimensionality from context is a different algebraic object — it's a natural transformation between functors indexed by dimension, not an element of the monoid. That's more machinery than it's worth.

Keep `zero-vector` with explicit `dims`. It's honest about what it is: a sized zero vector. The Rust already creates `vec![0.0; dims]`. Let the specification say so too.

### 4. Bare strings in fact constructors — tagged strings or newtypes?

The docstring is sufficient. Wat is a specification language, not a type-checked compiler. The four fact constructors have two-word signatures with clear positional semantics: `(fact/zone indicator zone)`, `(fact/comparison predicate a b)`. If you can't tell which string is which from the parameter name, newtypes won't save you.

Adding tagged strings or newtypes to a specification language creates ceremony without catching real errors. The wards catch structural misuse. The curve catches semantic misuse. That's enough.

### 5. Two files or one?

Two files. `std/facts.wat` produces Vectors. `std/statistics.wat` produces Floats. Different output types, different concerns, different dependency profiles. A program that needs `fact/zone` may not need `stddev`. A program that needs `mean` may not use the vector algebra at all.

The existing stdlib already separates by concern: `patterns.wat` is its own file. Follow the precedent.
