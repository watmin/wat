---
name: propose
description: Structure raw thoughts into a design proposal. Typed by scope — algebra, structural, or userland.
argument-hint: <algebra|structural|userland> [description of the idea]
---

# Propose

Take the datamancer's raw thoughts and structure them into a design proposal that the designers can review.

## Scope — the first argument determines the lens

**`/propose algebra`** — proposing a change to the two algebras (vector or journal).
- The bar is highest here. Every form must be algebraically essential.
- The proposal must be domain-agnostic. No trading concepts. No BTC. No candles.
- Ask: does this NEED to be in the algebra? Or can structural forms or stdlib express it?
- Reject application-specific types. If the proposal mentions a domain, it's leaking.

**`/propose structural`** — proposing a program organization form (defrecord, etc.).
- Wat specifies programs, not just algebras. Programs need structure beyond the two algebras.
- The bar is high but different: must be structurally essential. The question is "can programs be organized without this?" not "can the algebra express this?"
- Domain-agnostic. The form serves any wat program, not just trading.

**`/propose userland`** — proposing a change to how an application uses wat.
- The proposal uses existing forms. No new language forms.
- Ask: are we using the primitives and structural forms correctly?
- The designers review whether the APPLICATION design composes.
- Domain-specific concepts are expected and correct here.

## What to produce (all modes)

1. **The current state.** What exists today. What works.

2. **The problem.** What can't be expressed or what's wrong.

3. **The proposed change.** Expressions, architecture, or new forms — depending on scope.

4. **The algebraic question.** Does this compose with the existing monoid (bundle/bind)? Does it compose with the state monad (journal)? Does it introduce a new algebraic structure?

5. **The simplicity question.** Is this simple or easy? What's being complected? Could existing forms solve it?

6. **The questions for designers.** Specific, numbered, crisp.

## What NOT to produce

- Implementation details (Rust internals).
- Urgency arguments.
- **In algebra mode:** application-specific types, domain vocabulary, structural concerns.
- **In structural mode:** algebraic justifications. Structural forms don't need to compose with bind.
- **In userland mode:** proposals for new language forms. Switch to algebra or structural mode.

## The output

Write the proposal to `docs/proposals/YYYY/MM/NNN-short-name/PROPOSAL.md` relative to the current working directory. Create the directory if needed. Number sequentially within the month.

The document is ready for `/designers`. The datamancer reviews and approves before the designers see it.
