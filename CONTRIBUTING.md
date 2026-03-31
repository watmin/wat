# Contributing to Wat

## The Language

Wat has two algebras and a stdlib. Changes to the language go through
the proposal process. Application-specific code belongs in application repos.

### Proposing a language change

Use `/propose core` to structure the idea, then `/designers core` to review it.

The bar is high: every primitive must be essential. "Convenient" is not
enough. If existing primitives can express it, it belongs in the stdlib.

### Adding a stdlib operation

1. Write the operation in the appropriate `std/*.wat` file
2. Add it to the stdlib section of `LANGUAGE.md`
3. The operation must be derivable from core primitives — stdlib is convenience, not power

### Writing an example

Examples live in `examples/`. They demonstrate how the primitives compose
into programs. Every binding in an example should be either a parameter
or a let-binding — no free variables.

### The process

```
idea → /propose core → PROPOSAL.md
     → /designers core → review-hickey.md + review-beckman.md
     → datamancer writes RESOLUTION.md
     → implement (if accepted)
```

Proposals live in `docs/proposals/YYYY/MM/NNN-short-name/`.

## Application Vocabulary

Domain-specific vocabulary modules (trading indicators, game concepts, etc.)
belong in the APPLICATION repo, not here. The language provides the algebra.
Applications provide the vocabulary.

For the trading lab's contribution guide (adding vocab modules, wiring into
expert dispatch, running benchmarks), see the trading lab's own CLAUDE.md.

## Encoding Rules

Every value has a nature. The encoder matches the nature.

| Value nature | Encoder | Example |
|---|---|---|
| Fraction [0, 1] | `encode-linear` | accuracy, ratio |
| Orders of magnitude | `encode-log` | ATR, volume |
| Periodic/cyclical | `encode-circular` | hour (24), day (7) |
| Named category | atom | session, zone |
| Below 3/√dims | silence | noise floor |

Never use empirical scales. Always use theoretical range.
