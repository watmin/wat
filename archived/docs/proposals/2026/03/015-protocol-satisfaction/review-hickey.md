# Review: Rich Hickey

Verdict: CONDITIONAL

## The right question, poorly framed

The proposal sets up three options as if they were architectural
choices of equal weight. They are not. The question is not "explicit
vs convention vs hybrid." The question is: what is a specification
language *for*?

## What dispatch taught me

In Clojure, protocols dispatch on the first argument's type. You
never write a mapping table because the runtime resolves it — the
type of the thing *is* the connection between the protocol function
and the implementation. The mapping is the type system.

But wat has no dispatch. It's check-only. So you don't have a
runtime to resolve anything. You have a forge that reads declarations
and checks them. This is a fundamentally different situation, and
the Clojure analogy breaks down exactly here.

## Convention is coupling in disguise

Option B says: the forge infers `sma-step` satisfies `step` because
the name matches a pattern. This is implicit coupling — the worst
kind, because it works until it doesn't, and when it stops working
the failure mode is silent.

The proposal itself identifies the problem: `new-sma` follows
`new-{name}`, not `{name}-new`. So the convention is already
inconsistent in the existing codebase. You'd need a special case for
constructors. Then another special case. Then the convention becomes
a set of rules that nobody can hold in their head. That's not a
convention, that's an undocumented type system.

Conventions are fine for humans reading code. They are not fine for
machines checking specifications. A specification language should
*say what it means*. If `sma-step` implements `indicator/step`, write
it down. The forge should check what you declared, not guess what
you meant.

## Option A is correct, but the concern about boilerplate is real

The objection to Option A is boilerplate: `:step sma-step` is noise
when you can see it from the name. But look at what you're actually
writing. One `satisfies` form per (struct, protocol) pair, with one
keyword per protocol function. For the indicator protocol with three
functions, that's three lines. Three lines that tell you exactly
what implements what.

Compare that with the bug you'd get when someone renames `sma-step`
to `sma-advance` and the forge silently stops recognizing the
satisfaction under Option B. Which costs more — three lines of
declaration, or an afternoon debugging a silent failure?

Explicit is not boilerplate. Explicit is the point.

## The hybrid is the worst option

Option C is the disease dressed up as the cure. It says "convention
by default, explicit when names diverge." This means every reader
must ask: "Is this using convention or override? Which functions are
mapped implicitly and which explicitly?" You've created two modes
of understanding for one form. That's complexity.

When I said "simple is not easy," this is what I meant. The hybrid
*looks* easier — less typing in the common case. But it's not
simpler. It has more rules, more modes, more ways to be surprised.

## The exhaustiveness question

Yes. `satisfies` must be exhaustive. If the protocol declares three
functions and you map two, that is an error. Not partial satisfaction.
Not a warning. An error.

The entire value proposition of protocols is that they represent a
*complete* contract. A type either satisfies the whole contract or
it doesn't. Partial satisfaction is a different concept — it's
subtyping, and you haven't proposed subtyping, so don't sneak it in
through the back door.

## What I would do for a specification language

A specification language is a language of declarations. Its job is
to be legible and checkable. Every fact should be stated exactly once,
in exactly one place, with no inference required.

Option A. Full stop.

One `satisfies` per (struct, protocol) pair. All mappings explicit.
All protocol functions required. The forge checks existence, arity,
and first-argument type. Nothing is inferred. Nothing is implicit.

The mapping table is not boilerplate — it is the specification. It's
the part where you say "this function, right here, is how this type
fulfills this contract." That's the most important thing the
`satisfies` form does. Don't hide it.

## Conditions

1. Option A. No convention-based inference. No hybrid.
2. Exhaustive satisfaction — omitting a protocol function is an error.
3. Drop the "Rust mapping question" framing from the proposal. The
   Rust mapping is a compilation concern. The specification should be
   designed for clarity of intent, not ease of code generation. That
   it maps cleanly to `impl Trait for Struct` is a nice property, not
   a design driver.
