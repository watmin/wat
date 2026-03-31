# Resolution: Proposal 004 — Journal Operations

Status: **ACCEPTED**

Both designers accept. The Proposal 003 tension is resolved.

## The decision

observe/predict/decay move to core. std/journal.wat is deleted.

## Why

The journal is opaque state. No composition of the six public primitives can implement observe/predict/decay — they require privileged access to hidden state. The consistency argument is dispositive: curve reads journal internals and lives in core. predict reads journal internals and was in stdlib. No principled reason for the asymmetry.

Hickey reversed his Proposal 003 position: "conceptually equivalent" and "expressible as a wat expression" are different claims. The opacity makes the difference.

## The structure

core/primitives.wat has two sections:

**Vector algebra** — four generators:
- atom, bind, bundle, cosine

**Journal coalgebra** — one generator, five forms:
- journal (constructor)
- observe (state transition)
- predict (observation)
- decay (aging)
- curve (evaluation)

Five generators. Nine forms. The tagline becomes "five generators" not "six primitives."

## The general rule (from Beckman)

If a type is opaque, its interface operations are core. This follows from journal opacity + stdlib expressibility contract.

## What to implement

1. Move observe/predict/decay from std/journal.wat into core/primitives.wat
2. Delete std/journal.wat
3. Reorganize core/primitives.wat into two sections (algebra + coalgebra)
4. Update LANGUAGE.md to reflect five generators, nine forms
