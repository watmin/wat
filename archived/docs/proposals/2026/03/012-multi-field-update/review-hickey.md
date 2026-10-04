# Review: Rich Hickey

Verdict: **Accept with one semantic constraint.**

The proposal is sound. Nested `update` is incidental complexity — it obscures the intent, which is "produce a new record differing in these fields." The multi-field form removes nesting without adding a new concept. That's the definition of simplification.

---

## Question 1: Original state, not intermediate.

Later fields must see the original record. This is not a style choice — it's a consequence of what update *means*.

If `:b` sees the result of `:a`'s change, then field order is load-bearing. The expression is no longer a declaration of "what the new record looks like" — it's a sequence of imperative steps wearing a functional costume. You've reintroduced place-orientation through the back door.

Parallel semantics: all field expressions evaluate against the same input record, all results are assembled into the output. No field depends on another field's update. This is what `assoc` does in Clojure — and it's what makes it simple. You can reorder the pairs and nothing changes. That's the test.

If someone genuinely needs sequential threading — field B depends on the new value of field A — that's a `let` binding followed by an `update`. Make the dependency explicit. Don't hide it inside evaluation order.

## Question 2: Core, not stdlib.

`update` is already a core structural form. Extending its arity is not adding a new form — it's completing the one you have. `bundle` is variadic in core. `bind` is binary in core because binding is inherently binary. `update` is inherently n-ary — you just haven't said so yet.

Putting it in stdlib would mean core has the incomplete version and stdlib has the real one. That's the wrong factoring. The simple thing goes in core. This is the simple thing.

## Question 3: Follow `assoc`, diverge from Haskell.

The proposed syntax `(update record :field1 val1 :field2 val2)` is exactly right. It's `assoc` semantics on your product types. Keyword-value pairs are already the wat idiom for struct construction and projection. This is consistent.

Haskell's record update syntax `r { a = 1, b = 2 }` introduces braces and equals signs — new syntax for a concept you already have syntax for. That's complexity for no gain.

Don't invent. Extend what's there. The pairs pattern is already there.
