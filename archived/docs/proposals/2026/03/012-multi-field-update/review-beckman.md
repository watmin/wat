# Review: Brian Beckman

Verdict: **Accept.**

This is a correct and conservative extension. You are widening the arity of an existing form, not introducing new structure. The categorical picture is untouched: you still have a product, you still have projections, and `update` still constructs a new object in the fiber over the same product type. Nothing here changes the universal property. It is the same morphism applied to more components at once.

## Answers to the three questions

### 1. Original or intermediate?

Original. Each right-hand side sees the record as it was *before* the update form began. This makes multi-field update a **parallel assignment** -- the field expressions are independent, their order in the source text is irrelevant to the result, and reordering them is a valid refactor that changes nothing. If you choose sequential semantics, you introduce an implicit data dependency between lines that look independent. That is the opposite of clarity. Parallel is the only choice consistent with the stated goal of being clearer than the Rust.

(If someone genuinely needs sequential threading -- field B depends on the new value of field A -- they nest two updates explicitly. That nesting *earns its keep* because it signals a real dependency.)

### 2. Core or stdlib?

Core. `update` is already in `structural.wat`. The variadic extension is the same form with the same semantics, just iterated. Splitting it into two locations (single in core, multi in stdlib) would force the reader to chase a definition across files for what is, algebraically, one operation. `bundle` sets the precedent: variadic in core. Follow it.

### 3. Is there a better form?

No. `(update record :field1 val1 :field2 val2)` is the right syntax. It is already the Clojure `assoc` convention, which has two decades of evidence that programmers read it correctly. Haskell's record-update braces would introduce a new bracketing form for no algebraic gain. The keyword-value alternation is self-punctuating -- every odd position is a keyword, every even position is an expression. A reader can scan the field names without parsing the value expressions. That is exactly what a specification language needs.
