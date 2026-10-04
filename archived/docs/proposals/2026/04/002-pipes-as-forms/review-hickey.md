# Review — Proposal 016: Pipes as Forms

**Reviewer:** Rich Hickey (simulated)
**Date:** 2026-04-10

---

## The five answers

**1. Three forms or one?**

One. `defprocess` is sufficient. A service is a process whose input happens to be a multiplexed set of client pipes. The difference is topology, not kind. If you make `defservice` a separate form, you are encoding a deployment decision into the grammar. Tomorrow you will have a process that is *sometimes* a service (N=1 vs N=4 depending on configuration). Then you need a third form, or you need to explain why `defservice` with N=1 is not `defprocess`. One form. The topology is data — pipe declarations, not process declarations.

**2. Should `drain` be a form?**

No. It is a pattern over `try-recv` and a counter. The body you wrote is five lines of `loop`/`when-let`/`inc!`. That is already expressible. Adding `drain` to the grammar buys you one less line per call site at the cost of one more thing every ward, every tool, and every reader must know. The MAX_DRAIN constant is the important thing. Name the *constant*, not the *loop*.

**3. Capacity on the pipe or on the process?**

On the pipe. A pipe is a value with semantics. `bounded 1` means "this boundary enforces lockstep." That is a property of the boundary, not of who holds it. If two processes share a pipe, the capacity must agree — putting it on the process means you can disagree. Put it on the pipe. Once. Done.

**4. Should `loop` be explicit or implied?**

Explicit. A process that does not loop is a function — you said so yourself. Good. That means the loop is the *defining characteristic* of a process. If you hide it, you hide the thing that matters. Explicit loop also lets a process do setup before looping and teardown after. Implied loop cannot express `(let ((state (init))) (loop ...))` without inventing an `:init` clause, which is just a worse `let`.

**5. Does this complect the wat?**

This is the real question and the answer is: not if you do it right.

The six primitives are algebra. The pipes are coordination. These are orthogonal concerns. Algebra does not know about pipes. Pipes do not know about algebra. They compose — a process body *uses* algebra, but `defprocess` itself says nothing about vectors.

The danger is not in adding pipe forms. The danger is in adding too many. You proposed five new forms: `defpipe`, `defprocess`, `defservice`, `drain`, `select-ready`. I count two that earn their place: `defpipe` (a typed boundary) and `defprocess` (a persistent thread). The other three are either redundant (`defservice`), expressible from existing forms (`drain`), or low-level plumbing that belongs in the host (`select-ready` maps directly to crossbeam's `Select` — let it stay there).

Two forms. Not five.

## Verdict

**ACCEPT with reduction.** Add `defpipe` and `defprocess`. Drop `defservice`, `drain`, and `select-ready`. The wat gains the ability to specify CSP architecture — which closes the gap you identified — without growing the language beyond what it earns.

The heartbeat remains the fold driver. The pipes feed it. They do not replace it.
