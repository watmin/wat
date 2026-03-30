# Resolution: Proposal 003 — Language Layers

Status: **ACCEPTED with tension**

Both designers accepted the four-layer model. One tension unresolved.

## The decision

Four named layers (drop numbers per Beckman):

- **Syntax**: compiler builtins — define, let, if, map, filter, fold, require
- **Core** (`core/`): the six VSA primitives — atom, bind, bundle, cosine, journal, curve
- **Stdlib** (`std/`): derived operations — permute, encode-log, difference, gate, etc.
- **Userland** (`mod/`): domain-specific vocabularies and programs

## Agreed actions

1. **Delete `std/channels.wat`** — the pub/sub runtime contract contradicts Proposal 002. Channels are compile-time wiring expressed as function calls inside a fold. Wiring documentation moves to LANGUAGE.md.

2. **Strip `core/primitives.wat`** — remove derived patterns and the "additional holon operations" wishlist. Core is the six primitives, nothing more.

3. **Move derived patterns to `std/`** — permute, encode-log, difference, gate, etc. become stdlib `.wat` files.

4. **`online-subspace` stays in stdlib** — both designers agree it's not a seventh primitive.

## Unresolved tension: observe/predict/decay

**Hickey**: move to stdlib. They're derivable — observe is bundle, predict is cosine, decay is scalar multiply. The journal is opaque state but the operations are compositions of the six.

**Beckman**: keep in core. They're co-generators of the journal coalgebra. You can't express observe as just bundle — the journal maintains internal state (accumulators, recalib counter) that bundle alone can't access.

**The datamancer's interim decision**: implement Hickey's version (move to stdlib), then re-run the designers with the reorganized code. If the tension persists after seeing the actual separation, it needs a dedicated proposal.

## Next steps

1. Implement the agreed actions (delete channels, strip core, move derived to std/)
2. Commit with proposal attribution
3. Re-assess observe/predict/decay placement with fresh designer review if needed
