# Wat

An s-expression language for algebraic cognition.

Two algebras. Everything else composes.

```scheme
(atom "momentum")                              ; name a concept
(bind role filler)                             ; compose two concepts
(bundle fact1 fact2 fact3)                     ; superimpose into one thought
(cosine thought discriminant)                  ; measure similarity
(journal "name" 20000 500)                     ; accumulate labeled observations
(curve journal)                                ; evaluate prediction quality
```

## What Wat Is

Wat is the intermediate representation between human intuition and machine execution.
The human generates wat programs. The machine compiles them to Rust. The Rust runs.
The ledger records. The cycle continues.

Wat IS Lisp, restricted to the algebra of hyperdimensional computing.

## Structure

```
wat/
├── core/primitives.wat           — vector algebra + journal coalgebra
├── core/structural.wat           — product types (struct, projection, update)
├── std/
│   ├── scalars.wat               — continuous value encoding (log, linear, circular)
│   ├── vectors.wat               — derived vector operations (permute, difference, attend)
│   ├── memory.wat                — online subspace (Template 2: reaction)
│   ├── patterns.wat              — gate (credibility annotation)
│   └── common.wat                — shared vocabulary (predicates, directions, lifecycle)
├── examples/enterprise.wat       — the first complete wat program
├── LANGUAGE.md                   — formal grammar
└── CONTRIBUTING.md               — wat-to-Rust implementation guide
```

Domain vocabulary modules (trading indicators, game concepts, etc.)
belong in the APPLICATION repo, not here. The language provides the
algebra. Applications provide the vocabulary.

## See Also

- `LANGUAGE.md` — formal grammar, core forms, stdlib, control forms
- `core/primitives.wat` — vector algebra + journal coalgebra
- `std/` — derived operations, scalars, memory, patterns
- `examples/enterprise.wat` — the first complete wat program

## Origin

Wat began as an English-like Lisp for natural language processing (2024).
It evolved into an algebraic cognition language through the holon trading
enterprise project (2026). The s-expression structure survived. The domain
matured from language to mathematics.

The architecture is the language. The language is the architecture.
