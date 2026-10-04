# Review: Rich Hickey

Verdict: **Accept both. Two files.**

## Answers

### 1. Do fact constructors belong in stdlib?

Yes. These are named compositions of existing primitives — the definition of what a stdlib is for. They establish a shared vocabulary for the universal pattern "domain concept becomes vector." Without them, every program invents its own binding convention, and two programs that both encode "indicator in zone" produce incompatible vectors because they chose different role structures. That's not simplicity through omission — that's accidental complexity through absence.

Four one-line defines. The cost of inclusion is near zero. The cost of exclusion is convention drift across every application.

### 2. Do statistics belong in stdlib?

Yes. `mean`, `variance`, `stddev`, `skewness` are not domain logic. They are arithmetic over lists. Every analytical program needs them. Putting them in the application is like putting `+` in the application.

`skewness` is the weakest candidate — only one usage noted. But it composes from `mean` and `stddev` which are already there, and any program doing distribution analysis will want it. Keep it. If you cut something, you'd cut it last, and I wouldn't cut it.

### 3. Should `(bundle)` with no args be the lazy identity?

No. A value should know what it is at the time of its creation. A "lazy identity that adopts dimensionality from context" is complecting the identity element with the operation that consumes it. The zero vector of a 4096-dimensional space is a concrete thing — 4096 zeros. It doesn't become something upon use.

Keep `zero-vector` with explicit `dims`. This is honest. The alternative — a value whose nature depends on future context — is exactly the kind of implicit coupling that makes systems hard to reason about. If `dims` is annoying to pass, that's a signal the caller already knows the dimensionality and should say so.

### 4. Bare strings in fact constructors — tagged strings or newtypes?

The docstring is sufficient. Wat is a specification language, not a type-checked runtime. Adding newtypes for `Indicator` vs `Zone` vs `Predicate` would complect the language with a type system it doesn't need. The strings flow through `atom`, which treats all strings identically. The distinction is semantic, and the semantics are carried by the function name and its docstring.

If you find yourself passing a zone where an indicator belongs, the resulting vector won't match anything in the journal, and the curve will tell you. The algebra is the type checker.

### 5. One file or two?

Two files. `std/facts.wat` and `std/statistics.wat`. The proposal already states the reason correctly: one produces Vectors, the other produces Floats. They have different types, different consumers, and different reasons to change. A program that needs `mean` but not `fact/zone` shouldn't require both. Separation by concern, not by convention.
