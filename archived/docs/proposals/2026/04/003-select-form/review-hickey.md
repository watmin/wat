# Review — Proposal 003: The Select Form

**Reviewer:** Rich Hickey (simulated)
**Date:** 2026-04-10

---

## Evaluation of options

**A. `select` as a match-like form.** This is `alt!`. I designed `alt!`. It works when you have a known, fixed set of channels. Your problem is N clients, each with multiple pipes — the arm count is 2N and dynamic. `select` with a static arm list does not express "for each of N clients, match on their lookup or install pipe." You would need `select` inside a loop over clients, which is just the ugly code with a nicer keyword.

**B. `serve` as a higher-level service loop.** This is `defservice` wearing a different hat. It declares handlers per message type and hides the event loop. The runtime manages idle, closed detection, multiplexing. If this is right, then so was Beckman in Proposal 002, and we should call it what it is.

**C. `drain-all` with explicit select-ready.** Half-measure. The closed-check and idle-block are still exposed. You moved one piece of plumbing into a helper and left two others sitting in the specification. This is refactoring, not design.

**D. `defservice`.** The thing I rejected.

## The four questions

**1. Specification or implementation?** The event loop is implementation. The handlers are specification. The ugly code is ugly because it interleaves both. The right answer separates them: declare what you handle, let the host manage how.

**2. Is `select`/`alt!` the right form?** No. `alt!` is for a fixed set of channels with non-uniform semantics per arm. Your encoder service has a uniform protocol across N clients. The right abstraction is not "match on which channel fired" — it is "here is the protocol, serve it." These are different problems. `alt!` solves the first. You have the second.

**3. Does the evidence change my position?** Yes. I was wrong to reject `defservice`. My argument was "a service is a process whose input happens to be multiplexed client pipes — the difference is topology, not kind." The ugly loop proves the difference is not just topology. A process has a body you write. A service has a protocol you declare. The body is derived from the protocol. That is a real semantic distinction — not a deployment decision, a design decision. Beckman was right.

**4. N copies or one multiplexed service?** One service, N clients. The multiplexing is the service's defining characteristic. If you instantiate N copies you get N caches instead of one shared cache. The shared mutable state is the reason this is a service and not N processes.

## Verdict

**Option D. `defservice` accepted.**

The language grows by one form. A service is not a process — it is a process plus a protocol plus shared state plus N-client multiplexing. That is enough semantic weight to earn its own word.

I owe Beckman a beer.
