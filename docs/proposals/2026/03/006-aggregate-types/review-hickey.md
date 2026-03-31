# Review: Rich Hickey

Verdict: CONDITIONAL

---

## Preamble

I read the proposal, the two algebras in `primitives.wat`, the grammar in `LANGUAGE.md`, and the enterprise program where the runes live. Let me take each question.

---

## Question 1: Is this a primitive or a convenience?

It is essential, but it is not a primitive of either algebra. That distinction matters.

`defrecord` does not generate vectors. It does not observe journals. It does not participate in bind, bundle, or cosine. It is structural plumbing -- it names the fact that values travel together. The two algebras are complete without it. No algebraic operation becomes possible that was not possible before.

But the 16-parameter heartbeat is not an algebraic problem. It is a program organization problem. And program organization is real. When you have 16 positional parameters, you have complected identity with position. Parameter 11 is `last-exit-price` only by convention. Swap parameters 11 and 12 and you get a silent bug. That is place-oriented programming -- the thing I spent a decade arguing against.

So: essential for the language as a program specification tool. Not essential for the algebra. This is a meaningful distinction. The algebra is closed. The language that hosts the algebra has a gap.

**Essential for wat-the-language. Not essential for wat-the-algebra.**

---

## Question 2: What is the access syntax?

The proposal offers three options. Let me simplify.

Dot access `(. state experts)` imports a syntax form that means nothing in the algebra. Keywords `(:experts state)` are Clojure's solution and I stand by them -- keywords are values, they double as functions, and they require no new syntax beyond what the reader already provides. Function access `(field record)` is ambiguous -- is `field` a function or a variable?

But wait. Wat is not Clojure. Wat has no runtime. Wat compiles to Rust structs. The access syntax is a specification notation, not an execution mechanism.

Given that: use keyword access. `(:experts state)` reads as "the experts of state." Keywords already exist in the construction syntax. Let them do double duty. No new reader forms. No dot. One mechanism for field naming in construction and access both.

**Keywords. One mechanism, two uses.**

---

## Question 3: Should records be opaque?

Yes. Emphatically.

Destructuring is a convenience that complects the consumer with the shape of the producer. The moment you destructure, you have coupled to field names and field count. Pattern matching on record fields is even worse -- it makes the record shape part of your control flow.

Records should be constructed (one way in), accessed by keyword (one way to read a field), and updated functionally (one way to derive a new record). Three operations. No destructuring. No pattern matching on fields. The record is a value -- you pass it, you access fields, you make new ones. That is sufficient.

If someone wants three fields out, they write three accesses. This is not a hardship. It is clarity about what you depend on.

**Opaque. Three operations. No destructuring.**

---

## Question 4: Does this change the compilation model?

The proposal dances around this. Let me be direct.

Today: a human reads wat and writes Rust. `defrecord enterprise-state` means the human writes `struct EnterpriseState { ... }`. That works. It is what Clojure `defrecord` does relative to Java -- it declares a class that the host platform materializes.

This does not push wat toward being a compiler. It pushes wat toward being a better specification. A `defrecord` is a declaration -- "these fields exist, they travel together, the struct in Rust should have these fields." The human translator now has an unambiguous target instead of reverse-engineering field groupings from parameter lists.

If anything, `defrecord` makes the compilation model simpler, not more complex. Sixteen parameters require the translator to track sixteen bindings. One record requires the translator to emit one struct and a constructor.

**No change. Better specification, same compilation model.**

---

## Question 5: Is `update` essential?

No.

`update` is derivable. Given construction and access:

```scheme
(enterprise-state
  :experts      (:experts state)
  :generalist   (:generalist state)
  ...
  :last-exit-price new-price)
```

This is verbose. It is also explicit. Every field is visible. Nothing is hidden behind a convenience form.

But I said the same thing about `assoc` in Clojure 1.0 and within a week I added it because the verbosity was drowning the intent. The 12-field reconstruction obscures the one field that changed. That IS complecting -- the signal (one field changed) is lost in the noise (eleven fields copied).

So: `update` is derivable but essential. Not because you cannot live without it, but because its absence forces you to write code where the structural noise exceeds the semantic signal. That is a form of complection -- accidental complexity masking essential complexity.

Include it. Single-field functional update. Not `update-in`, not `assoc-in`, not multi-field update. One field at a time. Compose if you need more.

**Essential. One field. No nesting.**

---

## Question 6: Where does it live?

This is the real question, and the proposal's answer matters more than any syntax choice.

`defrecord` is not algebraic. It does not compose with `bind`. It does not compose with `journal`. It is structural -- a product type for program state. The two algebras in `primitives.wat` are mathematically grounded: a commutative monoid with a group action and a coalgebra with labeled state transitions. `defrecord` is neither. It is a Cartesian product. Category theory says products exist in any reasonable category, but that does not make them part of your algebra. They are part of your ambient language.

The current `primitives.wat` header says: "Two algebraic structures. Nothing here is derivable from the others." A record IS derivable -- from the host language's ability to group values. It is not derivable from the two algebras, but it is derivable from "being a programming language."

Records belong in the host language layer. Not core alongside `atom` and `journal`. Not stdlib alongside `encode-linear` and `gate`. A third location: the structural substrate that the language provides so that programs can be organized.

Look at your own `LANGUAGE.md`. You have a "Host Language" section: `let`, `define`, `lambda`, `match`, `fold`. These are the ambient Lisp forms. `defrecord` belongs there. It is a host language form that the two algebras use but do not define.

Add a "Host Language" section to `primitives.wat` -- or better, a separate `core/structural.wat` -- that says: these are the program organization forms. `defrecord` lives there. Not mingled with the generators of the vector algebra. Not pretending to be algebraic.

**Host language layer. Not core. Not stdlib. Structural substrate.**

---

## Summary

The proposal is sound. The problem is real -- 16 parameters is complection, not simplicity. The solution is the right shape: a named product type with construction, access, and functional update.

My conditions:

1. `defrecord` goes in the host language layer, not in `primitives.wat` alongside the algebra generators
2. Keyword access, not dot syntax
3. Opaque -- no destructuring, no pattern matching on fields
4. `update` is included but restricted to single-field functional update
5. The algebra files (`primitives.wat`) remain untouched -- two algebras, no structural types mixed in

Meet these five conditions and the proposal is approved. The language needs this form. The algebra does not. Keep them separate and you keep your simplicity.
