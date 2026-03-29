---
name: propose
description: Structure raw thoughts into a design proposal for the wat language. Prepares input for /designers review.
argument-hint: [description of the idea]
---

# Propose

Take the datamancer's raw thoughts and structure them into a design proposal that the designers can review.

## What to produce

1. **The current state.** What exists today. What primitives are involved. What works.

2. **The problem.** What can't be expressed. What's missing. What contradiction or limitation prompted this proposal.

3. **The proposed change.** New primitives, new forms, extensions to existing forms. Show the wat expressions. Show what they compile to in Rust.

4. **The algebraic question.** Does this compose with the existing monoid (bundle/bind)? Does it compose with the state monad (journal)? Does it introduce a new algebraic structure? If so, is there a natural transformation to the existing one?

5. **The simplicity question.** Is this simple (not interleaved) or easy (familiar but complex)? What's being complected? Could the existing primitives solve it differently?

6. **The questions for designers.** Specific, numbered. Each question should have a clear "yes/no/it depends" shape. The designers argue better with crisp questions.

## What NOT to produce

- Implementation details. The designers don't care how Rust does it.
- Urgency arguments. "We need this for multi-asset" is motivation, not design.
- Solutions. The proposal presents the problem and ONE candidate solution. The designers find the right solution.

## The output

A structured document ready to be passed to /designers. The datamancer reviews and approves before the designers see it.
