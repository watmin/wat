# Review: Rich Hickey

Verdict: CONDITIONAL

Model A, with one caveat I'll get to.

---

## The essential question

You're asking: should we complect two distinct concepts for the sake of convenience, or separate them at the cost of ceremony? That's not actually the question. The question is: what is the essential complexity here, and which model reveals it?

Let me be precise about what you have.

You have a specification language. Not a general-purpose language. Wat specifies Rust implementations. The Rust runs. This changes everything about the analysis. You're not designing runtime semantics -- you're designing *how humans think about their programs*.

## What you actually need

I read your enterprise files. There are exactly two situations:

1. **A gate that says "no."** `curve-valid false`. The observer hasn't proven its edge. This is a boolean. It answers a yes/no question.

2. **A computation that might not produce a result.** `position-frac` returns a sizing fraction or nothing. `tick` returns a signal or nothing. `kelly-frac` needs 500 resolved predictions or it can't answer. These aren't "false" -- they're *absence*.

These are genuinely different things. The proposal is right to name both. `true`, `false`, `nil` -- three literals, three meanings. No argument there.

## Why Model A

Here's where the Rust people get confused. They look at `if` and `Option` and `bool` and say: different types, different control flow, different semantics, must keep them separate. And in Rust they're right. Rust is a language where the compiler catches category errors for you. That's what you pay the type system for.

But wat is not Rust. Wat is a specification language. Its job is to be *clear to humans reading it*, and to specify what the Rust should do without drowning in the Rust's type machinery.

Look at your `position-frac`:

```scheme
(if (= (:phase portfolio) :observe) #f
(if (< conviction min-conviction) #f
  ...))
```

What does `#f` mean here? It means "no position." Not "the answer to a yes/no question is no." It means absence. You're already using falsy-as-absence in the enterprise, and it reads fine. The human knows what it means. The problem isn't the semantics -- it's that `#f` is ugly borrowed syntax.

With Model A:

```scheme
(if (= (:phase portfolio) :observe) nil
(if (< conviction min-conviction) nil
  ...))
```

That's what you actually mean. And `when` is even cleaner:

```scheme
(when (>= (:phase portfolio) :tentative)
  (when (>= conviction min-conviction)
    ...))
```

Returns nil implicitly on either failure. The human reads "when this condition holds, compute the sizing." The nil is the absence of sizing. Clean.

With Model B you'd need to thread `Option` types through the specification, distinguish `if` from `if-let`, match on `Some` and `None`. All of that is Rust's ceremony leaking into your specification language. You'd be specifying the *type system's requirements* instead of specifying *what the program does*.

## The caveat

Model A is correct for wat *because wat is a specification language that compiles to Rust*. The Rust will separate bool from Option. That's the compiler's job. The specification should not recapitulate the compilation target's type distinctions when those distinctions add no clarity to human understanding.

But -- and this is the caveat -- your compiler needs to be able to *infer* which one it's looking at. The specification must be unambiguous even if the surface syntax doesn't force the distinction.

This is actually straightforward in your case. Look at the usage:

- `curve-valid` is declared as a struct field with boolean intent. The compiler knows it's `bool`.
- `position-frac` sometimes returns a number, sometimes returns nil. The compiler sees that and generates `Option<f64>`.
- `when` always returns `T | nil`. That's `Option<T>`.
- `if` with a boolean condition and no nil in either branch? Both arms are `T`. The condition is `bool`.

The type information is *already in the structure*. You don't need the programmer to annotate it. The compiler can recover the Rust types from the wat specification without the wat author ever writing `Option` or `bool`.

That's the right split of concerns. The human says what they mean in the clearest way. The compiler does the mechanical work of mapping it to Rust's type system.

## What existing forms can't do

Nothing, actually, handles this today. You're using `#f` as a borrowed Scheme-ism for both "no" and "absent," and `nothing` as a bare atom that's actually a vector. Both are wrong. The three literals are essential. They name what was previously unnamed.

## Does it complect with the algebra?

No. `true`, `false`, and `nil` are host language forms. They never enter the vector space. You can't `bind` a boolean. You can't `bundle` nil. They live in the structural layer alongside `struct` and `enum`, organizing the program's control flow. Orthogonal to the algebra. Good.

## The simple thing

Three literals. Truthiness: nil and false are falsy, everything else is truthy. `when` returns body or nil. `when-let` destructures non-nil. `if` works on truthiness.

The compiler maps truthiness to Rust's type system. The human never thinks about `Option<T>` vs `bool` in the specification.

That's simpler than two parallel control flow vocabularies. Simplicity is not about having fewer features. It's about having fewer concepts that interleave. Model B gives you two interleaving concepts where Model A gives you one.

## Conditions

1. Document the compiler's obligation: truthiness in wat maps to `bool` or `Option<T>` in Rust depending on structural context. This is the compiler's problem, not the specifier's.

2. Do not add `Option`, `Some`, `None`, `if-let`, or any Rust type machinery to the wat surface. If you find yourself needing those, the compiler isn't doing its job.

3. Replace `#f` with `nil` in `position-frac` and `tick` (they mean absence), and `#f` with `false` in `curve-valid` (that means "no"). The proposal's examples already show this distinction clearly.

Model A. Let the specification be clear. Let the compiler be smart.
