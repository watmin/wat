# Resolution: Proposal 001 — Stream Processor

Status: **REJECTED with open question**

## The decision

Both designers rejected all three options (defprocessor, convention-only, processor pragma). The six primitives remain six. No new form for declaring a stream processor.

## The disagreement

**Hickey** rejected flatly. The function shape `(state, event) → state` IS the declaration. The fold is the runtime's job. Adding syntax for it is a category error — mixing "what to compute" with "how to drive the computation."

**Beckman** rejected the three options but proposed something new: `fold` as a named control form. His argument: the journal is already a fold over observations. The heartbeat is already a fold over candles. The pattern exists at every level but is unnamed. Naming the catamorphism makes the self-similarity visible. Channels are the dual (anamorphism). Together they form the hylomorphism the enterprise already is.

## The open question

Is `fold` what the language is missing? Not `defprocessor` (which complects four concerns). Not a pragma (which is build metadata). But `fold` — the catamorphism that already exists unnamed at every level of the enterprise.

This question is forwarded to Proposal 002.

## What to do now

1. Refactor the heartbeat to take `(state, event)` — both designers agree on this.
2. Document the convention in LANGUAGE.md.
3. The `fold` question needs its own proposal with both designers reviewing together.
