---
name: propose
description: Structure raw thoughts into a design proposal. Typed by scope — core/std extension vs userland application.
argument-hint: <core|userland> [description of the idea]
---

# Propose

Take the datamancer's raw thoughts and structure them into a design proposal that the designers can review.

## Scope — the first argument determines the lens

**`/propose core`** — proposing a change to the wat language (core primitives or stdlib).
- The proposal must be domain-agnostic. No trading concepts. No BTC. No candles.
- Show the wat expressions. Show what they compile to.
- Ask: does this NEED to be in the language? Or can userland express it with existing primitives?
- The bar is high: every primitive must be essential. "Convenient" is not enough.
- Reject application-specific types in language proposals. If the proposal mentions a specific domain, it's leaking userland into core.

**`/propose userland`** — proposing a change to how an application uses wat.
- The proposal uses existing primitives. No new language forms.
- Ask: are we using the six primitives correctly? Is the architecture honoring the algebra?
- The designers review whether the APPLICATION design composes, not whether the LANGUAGE needs extension.
- Domain-specific concepts are expected and correct here.

## What to produce (both modes)

1. **The current state.** What exists today. What works.

2. **The problem.** What can't be expressed or what's wrong.

3. **The proposed change.** Expressions, architecture, or new forms — depending on scope.

4. **The algebraic question.** Does this compose with the existing monoid (bundle/bind)? Does it compose with the state monad (journal)? Does it introduce a new algebraic structure?

5. **The simplicity question.** Is this simple or easy? What's being complected? Could existing primitives solve it?

6. **The questions for designers.** Specific, numbered, crisp.

## What NOT to produce

- Implementation details (Rust internals).
- Urgency arguments.
- **In core mode:** application-specific types, domain vocabulary, userland concepts.
- **In userland mode:** proposals for new language primitives. If you need a new primitive, switch to core mode.

## The output

A structured document ready for `/designers`. The datamancer reviews and approves before the designers see it.
