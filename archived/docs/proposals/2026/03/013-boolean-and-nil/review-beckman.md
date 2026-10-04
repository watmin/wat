# Review: Brian Beckman

Verdict: CONDITIONAL

Model B, with one refinement. Here is why.

## The categorical question

What is this proposal actually constructing? It is introducing two
distinguished objects into the ambient category of wat's type system:
the terminal object (Bool, a two-element set) and a family of pointed
objects (Option, each type extended with a base point nil). These are
distinct universal constructions. Collapsing them into one truthiness
relation, as Model A does, is the categorical equivalent of declaring
that the terminal object and the free pointed-set functor are the same
thing. They are not.

Bool is the classifier of subobjects. It answers questions. Given a
predicate P on some object X, the characteristic morphism X -> Bool
factors through the subobject classifier. This is what `curve-valid`
is: the observer has proven its edge, or it has not. The answer exists.
It is false.

Option is the Maybe monad. It is the free pointed-set functor applied
to a type. The base point (nil) does not answer a question — it
witnesses the absence of an answer. This is what `tick` returns: either
a signal happened, or nothing happened. There is no "false exit signal."
There is no exit signal.

These are different arrows in different diagrams. Model A merges them.
Model B keeps them apart.

## What the enterprise code actually says

Look at `position.wat`, line 77-78:

```scheme
(define (tick pos current-price k-trail)
  "Update position with current price. Returns :stop-loss | :take-profit | #f."
  (if (= (:phase pos) :closed) #f
```

That `#f` is doing duty as nil. The return type is conceptually
`Option<ExitSignal>`, not `Bool`. The function does not return "no, not
a stop loss." It returns "nothing happened." The current code uses `#f`
because wat has no nil, and this is exactly the confusion the proposal
aims to fix.

Now look at `observer.wat`, line 47:

```scheme
      :curve-valid false)))
```

That `false` is genuinely boolean. The observer has not yet proven its
curve. The answer to "is the curve valid?" is no. Not "there is no
answer" — the answer is no.

And `portfolio.wat`, line 96-97:

```scheme
  (if (= (:phase portfolio) :observe) #f
  (if (< conviction min-conviction) #f
```

Again, `#f` masquerading as nil. The function returns a position
fraction or nothing. It does not return "false position fraction."

Model A would let all three of these sites use `#f`/`false`/`nil`
interchangeably and the compiler would sort it out. That is precisely
the problem. The compiler cannot sort it out without knowing which
diagram the programmer intended, because the two constructions have
different composition laws.

## What goes wrong at the boundary

The critical failure mode is composition across the bool/Option boundary.
Consider:

```scheme
(and (curve-valid observer) (position-frac portfolio conviction ...))
```

Under Model A, this "works." If `position-frac` returns nil (no
position), `and` short-circuits and returns nil, which is falsy. But
the result is now simultaneously "the curve is valid AND there is no
position fraction" collapsed into one falsy value. You have lost
information. Was it the curve that failed, or the sizing? The truthiness
conflation destroys the provenance of the failure.

Under Model B, this is a type error. `curve-valid` returns Bool.
`position-frac` returns `Option<Float>`. You cannot `and` them. You
must be explicit:

```scheme
(when (:curve-valid observer)
  (when-let ((frac (position-frac portfolio conviction ...)))
    frac))
```

Two levels of nesting, two different questions answered at each level.
The structure of the code mirrors the structure of the logic. This is
what structural honesty means.

## Why Model A is seductive and wrong

Model A is Hickey's design for Clojure, and it is the right design for
Clojure. Clojure is a dynamic language running on the JVM with
persistent data structures and a philosophy of simplicity through
unification. Truthiness unification works there because Clojure does not
compile to a language that distinguishes the constructions.

Wat compiles to Rust. Rust's type system already distinguishes Bool and
Option at the machine level. Model A means the wat-to-Rust compiler
must reconstruct a distinction that the programmer deliberately erased.
The compiler must infer, from context, whether a falsy value was a
boolean false or a None. This is not hard for simple cases. It becomes
undecidable in general — you are asking the compiler to infer the
programmer's categorical intent from a degenerate representation.

More importantly: wat is a specification language. Its purpose is to be
read by humans and checked by machines. A specification language that
conflates two distinct universal constructions is a specification
language that permits ambiguity in the spec. The `#f` problem in the
current codebase is not a syntax problem. It is a specification problem.
Model A replaces one ambiguous token (`#f`) with two tokens (`false`,
`nil`) that are treated identically in conditionals, reproducing the
same ambiguity at a higher level of abstraction.

## The refinement

Model B as stated is correct but incomplete. The proposal says:

> Does not add Option/Maybe types. `nil` is the value. `when-let` is
> the pattern.

This is almost right. But if nil is a value that inhabits every type
(as in SQL nulls or Java nulls), you get Tony Hoare's billion-dollar
mistake: every type becomes implicitly optional, and you cannot
distinguish "this function always returns a Float" from "this function
might return nil."

The refinement: nil should be the *only* value of a distinguished
*unit type* that participates in Option via the existing coproduct
machinery. You do not need to add Option as a new form. You already
have `enum`:

```scheme
(enum exit-signal :stop-loss :take-profit)
```

The return type of `tick` is "exit-signal or nil." In categorical terms,
this is the coproduct `ExitSignal + 1`, where 1 is the terminal object
(the unit type whose only value is nil). The `when-let` form is the
copattern match on this coproduct.

You do not need to spell out `Option<ExitSignal>` in the surface
syntax. But the *specification* must be clear that nil does not inhabit
ExitSignal. It inhabits the coproduct. The type annotations (which the
proposal correctly notes are optional) should be able to express this:

```scheme
(define (tick [pos : ManagedPosition] [price : Float] [k-trail : Float])
  : ExitSignal?    ; the ? suffix means "or nil"
  ...)
```

The `?` suffix is sugar for the coproduct with the unit type. It is
not a new type constructor. It is a naming convention for an existing
categorical construction.

## The condition

Model B, with the understanding that:

1. `true` and `false` are the two values of Bool, the subobject
   classifier.
2. `nil` is the unique value of the unit type (1 in the ambient
   category).
3. These never mix in conditionals. `if` takes Bool. `when-let`
   destructs the coproduct T + 1.
4. The `?` suffix in type annotations (when used) denotes T + 1.
5. The existing `enum` machinery is sufficient — no new type
   constructor needed.

Under these conditions, the proposal preserves the algebra's
independence (Bool and Option are ambient-category constructions,
orthogonal to the vector algebra and journal coalgebra), lives cleanly
in the ambient category (products, coproducts, terminal object), and
produces better algebraic properties than Model A (no information loss
at composition boundaries).

The enterprise code will become clearer:

```scheme
;; position.wat — tick returns ExitSignal?, not bool-pretending-to-be-option
(define (tick pos current-price k-trail)
  (when (!= (:phase pos) :closed)
    (match (:direction pos)
      :long  (cond ((<= current-price trailing-stop) :stop-loss)
                   ((and (= (:phase pos) :active)
                         (>= current-price (:take-profit pos))) :take-profit)
                   (else nil))
      :short ...)))

;; observer.wat — curve-valid is genuinely Bool
(observer ... :curve-valid false)

;; portfolio.wat — position-frac returns Float?, not bool-pretending-to-be-option
(define (position-frac portfolio conviction ...)
  (when (!= (:phase portfolio) :observe)
    (when (>= conviction min-conviction)
      ...)))
```

Every `#f` in the current code becomes either `false` (the answer is
no) or `nil` (there is no answer), and the choice is enforced by the
type system, not by convention.

That is the refinement. Model B, with nil as the unit type's
inhabitant and `?` as sugar for the coproduct. Approved conditionally
on this clarification making it into the final spec.

--- Brian
