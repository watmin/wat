# Review: Rich Hickey

Verdict: **Accept.**

The old gate complects projection with annotation. The new one doesn't. That's the whole story.

## Answers

**1. Does `opinion` belong in stdlib or in the enterprise?**

Enterprise. It knows about buy/sell. It knows about linear encoding of cosine magnitude. These are decisions, not algebra. The gate pattern is generic — "annotate a vector with a status tag" — and earns its place in stdlib. The projection from Prediction to Vector is a domain choice. Domain choices live with the domain.

**2. Does the gate still belong in `std/patterns.wat`?**

Yes. `(bundle vec (bind expert-atom status))` is three primitives composed with a name. That's exactly what patterns.wat is for — named compositions. The name `gate` communicates intent: "this is where credibility enters the geometry." Inlining it loses the name, and names are how humans reason about composition. Keep it.

**3. Should `opinion` use struct projection syntax?**

Yes. `(:raw-cosine prediction)` is the right call site to demonstrate it. Prediction is an opaque struct. You project a field. That's what the syntax is for. The alternative — some accessor function or destructuring — would be more mechanism for the same information. The keyword-as-function form says what it means: "raw-cosine of prediction."

## Notes

The type violation is real. `bundle` takes Vectors. Prediction is not a Vector. The old code worked because the implementation silently coerced, but the spec doesn't promise that. When the spec and the implementation disagree, it's the code that's wrong.

The decomposition into `predict`, `opinion`, `gate` gives you three arrows that compose. You can use any prefix of the chain. You can test each independently. You can swap `opinion` for a different projection without touching the gate. That's the value of simple things — they compose in ways the author didn't anticipate.

Small change. Correct change. Ship it.
