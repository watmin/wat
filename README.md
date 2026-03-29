# Wat

An s-expression language for algebraic cognition.

Six primitives. Everything else composes.

```scheme
(atom "momentum")                              ; name a concept
(bind role filler)                             ; compose two concepts
(bundle fact1 fact2 fact3)                     ; superimpose into one thought
(cosine thought discriminant)                  ; measure similarity
(journal "name" 20000 500)                     ; accumulate labeled observations
(curve journal resolved)                       ; evaluate prediction quality
```

## What Wat Is

Wat is the intermediate representation between human intuition and machine execution.
The human generates wat programs. The machine compiles them to Rust. The Rust runs.
The ledger records. The cycle continues.

Wat IS Lisp, restricted to the algebra of hyperdimensional computing.

## Structure

```
wat/
├── core/           — the six primitives (corelib)
├── std/            — derived forms (stdlib)
├── mod/            — domain vocabulary modules
└── programs/       — complete wat programs
```

## See Also

- `LANGUAGE.md` — formal grammar, corelib, stdlib, control forms
- `core/primitives.wat` — the six primitives
- `std/common.wat` — shared vocabulary
- `std/channels.wat` — publish/subscribe communication contract
- `programs/enterprise.wat` — the first complete wat program

## Origin

Wat began as an English-like Lisp for natural language processing (2024).
It evolved into an algebraic cognition language through the holon trading
enterprise project (2026). The s-expression structure survived. The domain
matured from language to mathematics.

The architecture is the language. The language is the architecture.
