# Review — Proposal 003: The Select Form

**Reviewer:** Brian Beckman (category theory perspective)
**Date:** 2026-04-11

## Framing

I proposed `defservice` in 002. Hickey rejected it. The resolution
said "a service is a process with multiplexed clients." Fair enough.
Now 003 shows us what that multiplexed client looks like when you
actually write it down. The ugly loop on page one is the evidence I
predicted. The question is whether the right fix is the one I already
proposed, or something smaller.

## The four options

**A. `select` as match over pipes.** This is Go's `select`. It
handles the single-iteration problem cleanly — match on whichever
pipe is ready, dispatch. But it does not handle the N-client
indexing. You still need the `for-each-indexed` wrapper, the
closed-tracking, the pipe-list construction. It solves half the
ugliness. The half it solves is the right half for a *process*. It
is the wrong granularity for a *service*.

**B. `serve` as a higher-level service loop.** This is `defservice`
wearing a runtime hat instead of a declaration hat. The handlers
are the same. The client indexing is the same. The only difference
is that `serve` is an expression inside a process body rather than
a top-level form. That is actually worse — it means the service
semantics are invisible to the wards until runtime. A `defservice`
can be statically checked. A `serve` expression cannot.

**C. `drain-all` with explicit select-ready.** This is the honest
version of the status quo: name the pattern, keep the loop. It
reduces the ugliness from 15 lines to 5 without adding a new
concept. I respect it. But it still requires the programmer to
get the closed-check and the idle-block right. Every time. In
every service. That is the definition of a missing abstraction.

**D. `defservice`.** The form I proposed. Declares what a service
handles. The N-client protocol, the state, the handlers. The
event loop is the runtime's problem. The wards can verify that
every handler matches a pipe type, that the state is used
consistently, that no pipe is unhandled.

## Answers

**1. Specification or implementation?** Specification. The event
loop is the *defining characteristic* of a service. Hickey argued
in 002 that the loop should be explicit because hiding defining
characteristics hides what matters. I now agree for *processes*.
But for services, the defining characteristic is not the loop — it
is the protocol. The loop is identical across all services. Hide
the identical, expose the distinct.

**2. Go `select` or declaration?** Both. Option A belongs in the
language for processes that multiplex over a small fixed set of
pipes. Option D belongs for the N-client indexed pattern. They
serve different categories: A is a morphism combinator in **Proc**,
D is a natural transformation indexed by client count.

**3. Does the evidence change Hickey's position?** That is for
Hickey to say. But the evidence is unambiguous: the ugly loop
exists because the abstraction was rejected. The loop is identical
in every service. Identical code is a missing form.

**4. One client, N copies?** No. The N-client pattern carries
per-client state (which pipes are closed, which index maps to
which answer pipe). Instantiating N independent copies would
require external coordination that is strictly harder than the
indexed protocol. The multiplexing is a specification concern.

## Verdict

**A + D.** Add `select` for fixed pipe sets (it earns its place
in any concurrent language). Add `defservice` for N-client indexed
protocols (the evidence now demands it). Drop B and C — B is D
without static checkability, C is honest but insufficient.

I said this in 002. The code said it louder.
