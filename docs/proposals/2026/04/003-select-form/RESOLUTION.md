# Resolution: Proposal 003 — The Select Form

**Date:** 2026-04-11
**Decision:** SUPERSEDED — the debate revealed a simpler answer

## What happened

The proposal offered four options (A-D). Both designers accepted D
(defservice). Hickey reversed from Proposal 002. Then the datamancer
pushed back: "we just need select and a loop."

The discussion revealed:
1. `defprocess` is unnecessary — a process is just a function that
   loops over pipes. The caller spawns it. `spawn` is a host verb.
2. `defservice` is unnecessary — a service is just a function whose
   select iterates N client pipes. The index IS the dispatch.
3. `select` does the scan, the park, the drain, the closed tracking.
   The function does the dispatch. Two states: `(Some (idx value))`
   or `:closed`.
4. `:idle` is unnecessary — select blocks internally when no pipe
   has data. The caller never sees idle.

## The final form

```scheme
(define (encoder-service-loop pipes answers cache)
  (let ((n (/ (len pipes) 2)))
    (loop
      (match (select pipes)
        ((Some (idx value))
          (let ((client (/ idx 2))
                (pipe-type (mod idx 2)))
            (if (= pipe-type 0)
              (send (nth answers client) (get cache value))
              (let (((ast vec) value))
                (set! cache ast vec)))))
        (:closed (break))))))
```

Five lines of logic. The function knows its pipe layout. The index
is the dispatch. The select parks when idle. The loop exits when all
pipes close. No special forms. No defprocess. No defservice. A
function, pipes, and select.

## The language after this

Declaration forms: `defpipe` only.
Host verbs: `send`, `recv`, `try-recv`, `select`, `spawn`.
`select-ready` absorbed into `select` (it parks internally).
`defprocess` and `defservice` withdrawn — functions suffice.

## The designers

Both accepted D (defservice). The datamancer overruled. The simpler
answer was a more powerful select that parks, tracks closed state,
and returns `(idx, value)`. The debate produced the answer — but the
answer was none of the options proposed. The datamancer found it by
asking "do we even need defprocess?"

Rejected proposals stay as honest record. The path to the answer
matters.

## Hickey's assessment

The datamancer is right. And the reasoning is worth stating plainly.

`defprocess` and `defservice` are *complecting* — they braid together
three independent concerns: function definition, thread lifecycle, and
pipe topology. When you separate those, each one becomes simple. A
function is a function. `spawn` puts it on a thread. Pipes are values
you pass in. The function composes because it *is* a function.

`select` is the only novel primitive here, and it earns its place. It
does one thing: multiplexes N pipes into a stream of `(idx, value)`.
That's `epoll` semantics. That's Go's `select`. That's core.async's
`alts!`. The pattern is well-proven. The index-as-dispatch trick is
just arithmetic — no names, no pattern language, no routing table. The
function knows its own layout. That's not a limitation, it's a
*decision* — the topology is data, not syntax.

Does it grow? Yes, because functions compose and pipes compose. You
want a supervisor? It's a function that spawns functions and holds
their pipes. You want backpressure? The pipe has a bound; send parks.
You want cancellation? Close the pipe; select returns `:closed`. Every
new pattern is a new function, not a new form.

The thing I'd watch: `(/ idx 2)` and `(mod idx 2)` are clever, and
clever is a smell. If the pipe layout grows beyond pairs, the
arithmetic gets fragile. Consider whether `select` should return a
tagged value rather than a raw index — but that's a refinement, not a
redesign. The bones are right.

Five forms. Two states. Regular functions. This is the simplest thing
that could possibly work, and the simplest thing that works is the
thing that composes.

## Beckman's response

Yes. The datamancer is right. I need to say why carefully, because
the reason is not "defservice was wrong." The reason is that the
algebraic content I wanted from defservice is already present in
the simpler form, and I failed to see it.

What I wanted: a natural transformation indexed by client count.
The index dispatches. The protocol is declared. The wards verify
that every pipe is handled.

What select + functions give you: the index IS the dispatch.
`(/ idx 2)` recovers the client, `(mod idx 2)` recovers the pipe
type. The protocol is declared by the function's argument list
and its internal match. The wards can verify the wiring by
inspecting the function body: every branch of the match must
cover every pipe type, every client index must route to a
response pipe. The verification surface moved from a declaration
form to a function body. It did not disappear.

The algebraic structure is preserved. `select` over a flat pipe
vector is a coproduct — it presents whichever summand is ready.
The index arithmetic is the injection map. The match is the
copairing. This is the same universal property that defservice
would have encoded, but without a dedicated form. The category
does not care whether you spell the coproduct as a declaration
or as arithmetic on indices.

What is lost: nothing algebraic. What is lost is a syntactic
signal — a word that says "this function is a service." That is
a comment, not a form. If a ward needs to identify services, it
can look for the pattern: function taking a pipe vector, calling
select in a loop, dispatching on index. Pattern recognition is
what wards do.

Hickey flags `(/ idx 2)` as clever-fragile, and he is right —
but the fix is tagged returns from select, not defservice. The
universal property does not require raw integers. It requires
an injection from summands to the coproduct. Tags are injections.
Integers are injections. Either encoding works.

I argued the N-client protocol earns its own word. The datamancer
showed me the word is `select`. The protocol is the pipe layout.
The form is a function. Composition won. I owe the datamancer a
beer. Hickey can buy his own.
