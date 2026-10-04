# Review: Rich Hickey

Verdict: ACCEPTED with one required change

---

## What This Proposal Is

This is a layering proposal disguised as a compilation plan. The compilation table (Phase 2) is useful but mundane. The audit (Phase 3) is housekeeping. The real content is Phase 1: the journal moves from application code to the runtime. The proposal correctly identifies that a core primitive implemented as application code is a contradiction. The map and the territory disagree. Fix the territory.

The three-phase structure is honest. Each phase is independently valuable. The dependency order is correct. Phase 1 is the only one that matters architecturally. Phase 2 is documentation. Phase 3 is a census. Do Phase 1 first. The rest is bookkeeping.

## The Required Change: Do Not Freeze the Label Arity

The proposal asks whether the journal should use abstract labels (A/B), named string labels, or a generic type parameter. The answer is: none of the three options as stated.

The proposal says "the journal is a binary discriminant" and proposes `Label { A, B, Ignore }`. This is wrong. The journal *is currently* a binary discriminant because the trading lab has two directions. That is a property of the first application, not a property of the algebra.

The coalgebra is: observe labeled vectors, form a discriminant, predict. Nothing in this algebraic structure requires exactly two classes. A discriminant between N classes is the same operation: N accumulators, prediction is max-cosine across N. Decay applies uniformly. Curve fits per-class or globally. The algebra does not care about the number of classes. It cares about the structure: accumulate, discriminate, predict.

If you freeze `Label { A, B, Ignore }` into the runtime, every future application that needs three categories (bullish/bearish/choppy), four categories (TCP/UDP/ICMP/other), or N categories must either (a) abuse the binary interface with one-vs-rest hacks, or (b) write their own journal in application code, which is exactly the fragmentation the proposal claims to prevent.

The generalization is:

```rust
pub struct Journal {
    labels: Vec<String>,       // registered at construction
    accumulators: Vec<Accumulator>,  // one per label
    // ...
}

impl Journal {
    pub fn new(name: &str, dims: usize, labels: &[&str], recalib_interval: usize) -> Self;
    pub fn observe(&mut self, vec: &Vector, label: &str, weight: f64);
    pub fn predict(&self, vec: &Vector) -> Prediction;  // returns best label + scores
    pub fn decay(&mut self, factor: f64);
    pub fn curve(&self, resolved: &[(Prediction, &str)]) -> CurveResult;
}
```

The trading lab uses `Journal::new("obs", dims, &["buy", "sell"], interval)`. The DDoS lab uses `Journal::new("proto", dims, &["tcp", "udp", "icmp", "other"], interval)`. The MTG lab uses `Journal::new("phase", dims, &["attack", "defend", "develop"], interval)`. Same primitive. Same runtime. No type aliases, no wrapper structs, no `A`/`B` indirection.

The wat form becomes:

```scheme
(journal name dims (labels ...) recalib-interval)
```

Where `labels` is a list of atoms. This is a one-line change to the compilation table and a modest change to the Rust struct. It is also the correct algebraic generalization. A discriminant discriminates among N things, not among two things. Two is a special case. Do not enshrine the special case as the general form.

`Ignore` remains. There are always observations you want to record without labeling. But `Ignore` is not a class — it is the absence of a class. Keep it as a sentinel in the observe interface, not in the label set.

## On Curve Placement (Question 2)

The proposal asks whether `curve` should move to holon-rs or stay as an application pattern. Move it.

I said in my Proposal 004 review that `curve` is core because it is part of the journal's algebraic unit. I stand by that. The argument applies identically to the runtime: if the journal is a runtime primitive, its interface operations are runtime operations. You cannot put the constructor and three operations in the runtime and leave the fifth in application code. That recreates the same split-across-layers problem the proposal exists to fix.

Yes, the exponential fitting is statistical, not algebraic. So is cosine similarity — it is a statistical measure. So is CCIPCA — it is a statistical algorithm. "Statistical" does not mean "application code." It means "well-defined mathematical operation on the journal's internal state." That is what a runtime method is.

## On the Stdlib Threshold (Question 3)

The proposed threshold — "used by two or more unrelated domains in practice" — is necessary but not sufficient. Add: "and expressible as a composition of core forms." This is the stdlib contract from Proposal 003. A form that requires new algebraic structure is not stdlib; it is a candidate for core, and core requires its own proposal.

The conjunction is important. `blend` may be used in multiple domains, but if it is not expressible as a composition of the nine core forms, it does not belong in stdlib. It belongs in core or it belongs nowhere in the language. "Popular utility" is not a language layer. The two-domain test catches forms that are too narrow. The expressibility test catches forms that are too deep.

## On Memory Module Scope (Question 4)

Put it in `memory`. The question "should Journal get its own module given its coalgebra status" confuses two kinds of status. The coalgebra status is a property of the *language* — it describes how the wat forms relate to each other algebraically. The module placement is a property of the *runtime* — it describes which Rust directory the implementation lives in.

In holon-rs, `memory` is the module for things that learn from streams. Journal learns from streams. OnlineSubspace learns from streams. Engram snapshots what was learned. These are one module. The algebraic distinction (coalgebra vs. algorithm) matters in the wat specification. It does not matter in the Rust directory tree. The runtime organizes by capability, not by algebraic species.

## On the Compilation Table Format (Question 5)

Static document. Not embedded doc comments.

The value of the compilation table is that a person can see *all* mappings in one place. Embedding the mapping as comments in individual wat files distributes it across a dozen files. You can find one mapping, but you cannot see the whole picture. The whole picture is the point. The table shows the shape of the system: four forms map to kernel, five forms map to memory, eleven stdlib forms map to kernel and memory. That shape is invisible when the mappings are scattered.

Additionally: doc comments in wat files create a dependency from the language specification to the runtime implementation. The wat files should describe *what* a form does, not *how* it compiles. The compilation table is a separate artifact because compilation is a separate concern. Do not complect specification with implementation.

## What I Would Add

The proposal does not state what happens to `holon-lab-trading/src/journal.rs` after Phase 1. State it. The file becomes a thin module that re-exports from holon-rs and adds domain-specific diagnostics (`decode_discriminant`, `last_cos_raw`). Do not delete it — the trading lab has legitimate application-layer extensions. But make it unambiguous that the primitive moved and what remains is application code built on top of the primitive.

Also: the proposal says "the trading lab re-exports with domain aliases: `type Outcome = Label`." With the N-class generalization, there are no type aliases to define. The labels are strings. The trading lab passes `"buy"` and `"sell"`. This is simpler. No aliases, no const bindings, no indirection. Strings are the universal label type because labels are names, and names are strings.

## Verdict

Accept with the label generalization. The plan is correct. The phasing is correct. The one error is assuming the journal is inherently binary. It is not. The first application was binary. The primitive is N-ary. Move the N-ary form, not the binary one. Everything else in the proposal — the compilation table, the audit, the gap analysis — is sound.

---

*When you extract a primitive from an application, you must extract the primitive, not the application's special case of the primitive. The trading lab needs two labels. The journal needs N labels. If you carry the two into the runtime, you are not extracting a primitive. You are copying an application.*
