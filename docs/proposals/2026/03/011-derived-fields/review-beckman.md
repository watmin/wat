# Review: Brian Beckman

Verdict: **Accept with minor revision.**

The proposal is clean. You have a DAG of derived values over a product type, and you want a declaration form that says so. That is exactly what you should want. The alternative -- 55 `define` forms with no callers -- is a lie in syntax. A derived field is not a function. It is a projection whose value is determined by a computation over sibling projections. Saying that directly is better than encoding it indirectly.

## Question 1: Should `field` name its parent struct?

Yes. Always. The verbosity objection is wrong. When you write `(field raw-candle sma20 (sma close 20))`, the reader knows immediately which product type owns the derivation. When all 55 fields name the same struct, that is not redundancy -- it is a 55-fold confirmation that the struct is the right home. If you later split `raw-candle` into two structs (say, `candle-price` and `candle-indicator`), the refactor is mechanical: change the struct name in each `field` declaration. Without the name, you need scoping rules to determine ownership, and scoping rules are where languages go to accumulate debt.

The categorical reason: a derived field is a morphism in the slice category over the struct. The struct IS the base object. Omitting it is like defining a bundle without naming the base space.

## Question 2: Should fields reference other fields by name?

Yes, and the implicit resolution is correct. `(field raw-candle bb-upper (+ sma20 (* 2.0 (stddev close 20))))` -- here `sma20` resolves to the field of that name on the same struct. The DAG this creates is exactly the dependency graph the indicator engine needs. Making it explicit with `(:sma20 self)` would be more honest categorically (it is a projection composed with a computation), but the gain in precision is not worth the noise in 55 declarations. The implicit rule is: bare names in a `field` computation resolve first to sibling fields, then to the struct's own stored fields, then to stdlib. That is a short, predictable resolution order. Document it and move on.

One caveat: the topological sort must be total. If field A depends on field B, B must be declared (or exist as a stored field) before the sort runs. Circular dependencies are a static error. The proposal implies this but should state it explicitly.

## Question 3: Does `field` belong in `core/structural.wat`?

Yes. It operates on product types. That is the structural layer. The fact that it has build-time semantics (the computation is evaluated by the indicator engine, not at runtime) does not change its home -- `struct` itself is a compile-time declaration that generates Rust code. `field` is the same kind of thing: a declaration that extends the generated struct and generates a reducer. Both are structural declarations with compile-time effects. They belong together.

If you put `field` elsewhere, you create a false separation: "struct declares the shape" lives in one file, "field extends the shape" lives in another. The shape and its derived values are one specification. Keep them in one place.

## Question 4: Should `field` wait for proposal 004?

No. The form is well-defined independent of its implementation. `field` declares a derived value on a product type. Whether the implementation is a streaming reducer (proposal 004), a batch computation, or a SQL view does not change what the declaration means. The declaration is the specification; the implementation is the realization. You can accept the specification now and implement it when proposal 004 lands.

That said: if proposal 004 changes the semantics of what "computation" means in a `field` (e.g., if reducers need explicit window declarations that `field` does not currently carry), you will need to revise the form. The risk is low. SMA, RSI, Bollinger -- these are all sliding-window reducers. The computation expression already encodes the window size as a parameter. The form as proposed is sufficient.

## Summary

You have a product type. You have 55 derived projections on it. You want a declaration form that says "this projection is computed from these inputs." The form is `field`. It belongs in the structural layer, it should name its parent, it should allow implicit sibling references, and it should not wait for its implementation to be accepted as a specification. Ship it.
