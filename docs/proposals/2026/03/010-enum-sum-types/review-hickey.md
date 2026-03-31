# Review: Rich Hickey

Verdict: **Accept with reservations.**

The proposal is fundamentally sound. Products without coproducts is an incomplete vocabulary. You have structs; you need enums. The category theory is right: these are the two universal constructions. Adding one without the other was always temporary.

But I have concerns about complexity creep, and I think one of your four questions reveals a design smell.

---

## Question 1: Simple vs tagged — one form or two?

One form. Absolutely one form. A simple enum is a tagged enum where every variant carries unit. Splitting them into two forms is the kind of "helpful" distinction that doubles your surface area for zero expressive gain. Clojure doesn't have two kinds of maps because some maps hold scalars and some hold collections. A variant is a variant. Some carry data, some don't. One form.

```scheme
(enum direction
  (long)
  (short))
```

The parentheses aren't noise. They're the uniform structure that lets tooling, the forge, and the boundary checker treat every variant identically. `:long` as a bare keyword variant is sugar that creates a special case. Special cases are not simple.

## Question 2: Where does it live?

`core/structural.wat`, beside `struct`. This isn't even a question. Product and coproduct are the structural pair. They are orthogonal to the algebras. They carry values. The file is called `structural.wat`. Put the structural form in the structural file.

## Question 3: Must match be exhaustive?

Yes, and this is where the proposal earns its keep. The entire motivation is that without `enum`, keyword matches are open sets. An open match on a closed domain is a bug waiting to happen — you found three `_ =>` wildcards already. If `enum` declares a closed set and `match` doesn't enforce it, you've added a declaration nobody trusts. Exhaustiveness is the whole point.

But — and this matters — exhaustiveness is a property of the *specification*, not a runtime check. Wat is not interpreted. It specifies Rust. The Rust compiler already enforces exhaustive match. What `enum` adds is that the *wat-level* forge can verify it too, before the Rust is ever generated. Two layers of defense. The spec should say: "match on an enum must cover all variants. The forge checks this."

## Question 4: Keywords or atoms?

Keywords. This is not close.

Atoms are vectors. They live in geometric space. They have similarity. You can bind them, bundle them, measure cosine between them. `:long` and `:short` as atoms would mean `(cosine (atom "long") (atom "short"))` returns some similarity score. That's nonsensical. Directions are not "somewhat similar" to each other. They are discrete identities.

Enum variants are values, not geometry. Keywords are values. The proposal already says this: "Enum variants are identities, not geometric objects." Trust that sentence. Keywords.

The fact that structs project with keywords (`:field record`) and enums dispatch on keywords (`match ... :long ...`) is not a coincidence. It's consistency. Keywords are the structural vocabulary. Atoms are the algebraic vocabulary. Enums are structural. Keywords.

---

## The reservation

The tagged-enum syntax for `event` and `fact` is dangerously close to reinventing algebraic data types in a language that explicitly chose not to be general-purpose. Today it's `(enum fact (zone indicator zone-name) ...)`. Tomorrow someone wants `(enum ast (if cond then else) (let bindings body) ...)` and you're writing a type system.

Draw the line now: enum variants carry *fields from existing structs or scalars*. Not arbitrary nested structure. Not recursive types. If a variant needs complex data, it holds a struct. The enum names the alternatives; the struct names the shape. Keep them complementary, not competing.

This is the right addition. Just don't let it metastasize.
