# Review: Brian Beckman

Verdict: **Accept.**

This is a textbook factoring of a morphism into its honest components. The old gate was a composition pretending to be an atom. You found the seam and cut along it.

## The three questions

### 1. Does `opinion` belong in stdlib or in the enterprise?

In the enterprise. The function knows about `"buy"` and `"sell"` — those are domain atoms, not algebraic structure. The gate is generic: it annotates a vector with a credibility tag. The projection from Prediction to Vector is where the domain makes its lossy choice. Domain-specific projections live with the domain.

Stdlib should export `gate`. The enterprise should define `opinion`.

### 2. Does the gate still belong in `std/patterns.wat`?

Yes. `(bundle vec (bind identity status))` is small, but naming it matters. The name `gate` tells the reader "this is the credibility annotation point." Without the name, every call site reinvents the convention, and conventions drift. A one-liner with a good name is still a pattern.

### 3. Should `opinion` use struct projection syntax?

Yes, and it's an excellent first use. `(:raw-cosine prediction)` reads as "raw-cosine of prediction" — exactly the categorical product projection. The alternative would be some accessor function that hides the same thing behind an extra name. The keyword-as-function syntax makes the projection visible at the call site, which is the whole point of proposal 007. Using it here in the first function that needs to crack open a struct is the right place to establish the idiom.

## One algebraic note

The factoring `gate . opinion . predict` is clean because each arrow has a well-defined source and target:

```
predict : Journal x Vector  ->  Prediction
opinion : Prediction x Vector  ->  Vector
gate    : Vector x Vector x Bool  ->  Vector
```

The old gate smashed all three into one arrow with signature `Journal x Vector x Bool -> Vector`. That signature *hides* the intermediate Prediction — the caller can never inspect it, reuse it, or route it elsewhere. The new factoring restores the universal property: any consumer of Prediction can compose with `opinion` or not, independently of whether `gate` runs downstream.

This is the difference between a monolithic function and a composable pipeline. Small change, correct change.
