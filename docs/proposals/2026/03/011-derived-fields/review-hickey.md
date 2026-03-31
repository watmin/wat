# Review: Rich Hickey

Verdict: **Accept with modification.**

The proposal correctly identifies a real thing — a derived field is not a function, not a stored field, not a comment. It is a declaration of a computation that produces a value. Giving it its own form is honest. Dressing it up as `define` would be a lie; omitting the formula would be incomplete. The instinct here is sound.

But I have concerns about complecting.

## The four questions

### 1. Should `field` name its parent struct?

Yes, and it is not verbose — it is explicit. You have 55 fields. If you omit the struct name, you have 55 declarations floating in ambient scope, bound to their struct by... proximity? File convention? That is implicit coupling. `(field raw-candle sma20 (sma close 20))` says what it means. The struct name is load-bearing information, not ceremony. You will thank yourself when you have two structs.

### 2. Should fields reference other fields by name?

Yes, unqualified. `(+ sma20 (* 2.0 (stddev close 20)))` reads as a formula over the struct's namespace. Adding `(:sma20 self)` buys you nothing — there is no ambiguity when the scope is a single struct's fields, and you have already named the struct in the form. The DAG is implicit in the references and the engine topologically sorts it. This is the right division of labor: the wat declares dependencies by naming them, the Rust resolves order. Do not introduce a `self` — that is OO ceremony sneaking in through the back door.

### 3. Does `field` belong in `core/structural.wat`?

No. `struct` and `enum` are runtime type declarations — products and coproducts. They exist at every level of every program. `field` is a build-time directive that instructs a code generator. It belongs in a separate file — `core/derived.wat` or similar — that structural.wat does not need to know about. Keep the structural forms pure: they declare shapes. Derived fields are a layer above, consuming those shapes. Complecting "what the shape is" with "what computations extend the shape" is exactly the kind of entanglement that bites you later.

### 4. Should this wait for proposal 004?

No. The form is clear enough to adopt now. You have 55 uses already — the pattern is proven by practice, you are merely naming it. If proposal 004 changes the execution model, `field` still means the same thing: "this value is derived from these inputs." The declaration is stable even if the evaluation strategy changes. Ship the declaration. Let the engine catch up.

## One modification

The proposal says `(field struct-name field-name computation)`. Good. But add one constraint: **a `field` form must appear after its struct declaration, and may only reference fields (stored or derived) that are declared before it.** This makes the DAG lexically visible — you can read the file top to bottom and understand the dependency order. No forward references. The topological sort in Rust then becomes a verification step, not a discovery step. Declarations should be readable by humans in the order they are written.
