# Review — Proposal 016: Pipes as Forms

**Reviewer:** Brian Beckman (category theory perspective)
**Date:** 2026-04-10

## Framing

A process is an endofunctor: it takes (state, input) to (state, output). A pipe is a morphism between processes. Composition of processes via pipes forms a category -- call it **Proc**. The objects are process types (their state + port signatures). The morphisms are pipes whose `:carries` type matches the codomain of one process to the domain of another.

The proposal describes **Proc** but does not make it first-class. The forms let you declare objects (`defprocess`) and morphisms (`defpipe`) individually, but there is no composition operator. You cannot write "connect A's output to B's input" as an expression. The topology is implicit in name-matching: `obs-output` appears in one process's `:emits` and another's `:reads`. This is wiring by coincidence of names, not by composition.

Should the language make **Proc** first-class? Not necessarily yet. But the proposal should acknowledge that the category exists and that the current forms are its *presentation*, not its *algebra*. If you later want to reason about pipeline equivalence, refactor topologies, or verify that the diagram commutes (every message sent is received, no dangling pipes), you will need the composition operator. The forms as proposed are sufficient for *declaration* but not for *verification*.

## Answers to the five questions

**1. Three forms or one?**

Two. `defprocess` and `defservice` differ in their *arity of connection*: a process has fixed pipes, a service has N copies of a protocol. This is a genuine categorical distinction -- a service is a *natural transformation* between functors indexed by client count, not just a process with more ports. Keep both. But `defpipe` should stay separate from either: it is the morphism, they are the objects.

**2. Should `drain` be a form or a pattern?**

A form. The bounded drain is a *colimit* -- it computes the join of up to N pending messages. Naming it makes the bound explicit in the specification, which is where the ward can check it. A pattern buried in a loop body is invisible to static analysis.

**3. Capacity on pipe or process?**

On the pipe. The capacity is a property of the morphism, not the objects it connects. A bounded-1 pipe enforces lock-step regardless of which processes sit at its ends. If you move capacity to the process, you break the separation: the same process could not be reused with different backpressure policies. The pipe IS the contract.

**4. Explicit or implicit loop?**

Implicit. A `defprocess` that doesn't loop is, as you say, a function -- so don't allow it. The `loop` is the *fixpoint* that makes the process an endofunctor. Making it implicit removes one way to write a nonsensical process (one that exits after a single message). The body of a `defprocess` is one iteration of the fixpoint.

**5. Does this complect the language?**

No. The algebra (atom, bind, bundle, cosine, reckoner, curve) lives in a different category -- **Vect**, the category of vector spaces and linear maps. The pipes live in **Proc**. These are separate concerns connected by a functor: the process *uses* the algebra inside its body, but the pipe forms do not mention vectors. The language has two layers because the mathematics has two layers. Collapsing them would be the complection.

## Verdict

**Accept with one amendment.** Add a `defgraph` or `deftopology` form that wires processes and pipes into a closed diagram. Even if it is just syntactic sugar over the name-matching, it gives the wards a single place to verify that every pipe has exactly one sender and one receiver, and that the diagram commutes. Without it, the category exists but is invisible to the tools that need it most.
