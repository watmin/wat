# Proposal 005: Compilation Plan — wat Forms to holon-rs

Status: **DRAFT**

Scope: **core** — the mapping between the language and its runtime.

---

## 1. The Current State

The wat language has five generators and nine forms (Proposal 004, accepted):

**Vector algebra** (4 generators, 4 forms):
- `atom`, `bind`, `bundle`, `cosine`

**Journal coalgebra** (1 generator, 5 forms):
- `journal`, `observe`, `predict`, `decay`, `curve`

The stdlib has four modules:
- `std/vectors.wat` — permute, difference, negate, amplify, prototype, cleanup, attend, coherence
- `std/scalars.wat` — encode-log, encode-linear, encode-circular
- `std/memory.wat` — online-subspace, update, residual, threshold
- `std/patterns.wat` — gate (a named composition, not a new operation)

The runtime is holon-rs. It exists and is production-grade (~12x faster than the Python reference). Here is what it contains today:

**holon-rs has (kernel layer):**
- `VectorManager` — deterministic atom allocation. This IS `(atom name)`.
- `Primitives::bind` — element-wise multiplication. This IS `(bind role filler)`.
- `Primitives::bundle` — majority vote. This IS `(bundle fact1 fact2 ...)`.
- `Similarity::cosine` — cosine similarity. This IS `(cosine thought direction)`.
- `Accumulator` — frequency-preserving streaming sums. The BUILDING BLOCK of journal internals.
- `ScalarEncoder` — encode_log, encode_linear, encode_circular. These ARE the `std/scalars.wat` forms.
- `Primitives::permute`, `::difference`, `::negate`, `::amplify`, `::prototype`, `::cleanup`, `::attend`, `::coherence` — these ARE the `std/vectors.wat` forms.
- ~30 additional operations (blend, resonance, project, reject, segment, etc.) that are NOT in wat stdlib.

**holon-rs has (memory layer):**
- `OnlineSubspace` — CCIPCA incremental PCA. This IS `(online-subspace dims k)`.
- `OnlineSubspace::partial_fit` — this IS `(update subspace vector)`.
- `OnlineSubspace::residual` — this IS `(residual subspace vector)`.
- `Engram`, `EngramLibrary` — snapshot patterns. Not yet in wat stdlib.

**holon-rs does NOT have:**
- `Journal` — the coalgebra. Lives in `holon-lab-trading/src/journal.rs` as application code.
- `observe`, `predict`, `decay` — journal interface operations. Same file.
- `curve` — accuracy/conviction evaluation. Scattered across trading lab application code.

## 2. The Problem

There is no documented mapping between wat forms and holon-rs types. Three specific gaps:

**Gap 1: The journal coalgebra is not in the runtime.** The journal is a core primitive (Proposal 004). It is the only core form with no holon-rs implementation. It currently lives in the trading lab as application code (`holon-lab-trading/src/journal.rs`). This is the wrong layer. A core primitive belongs in the runtime, not in a domain application.

**Gap 2: The stdlib mapping is implicit.** `std/vectors.wat` forms map 1:1 to `Primitives::*` methods. `std/scalars.wat` forms map 1:1 to `ScalarEncoder::*` methods. `std/memory.wat` forms map 1:1 to `OnlineSubspace::*` methods. But this mapping is nowhere written down. A person reading the wat files cannot determine what Rust function implements each form without searching the holon-rs source.

**Gap 3: holon-rs has operations that wat does not name.** Blend, resonance, project, reject, segment, entropy, power, grover_amplify, drift_rate, and others exist in `Primitives` but have no wat form. These are either stdlib candidates or internal utilities. The distinction has not been made.

## 3. The Proposed Plan

Three phases. Each is independently valuable. Each has a clear deliverable. The dependency order is: Phase 1 before Phase 2. Phase 3 is independent.

### Phase 1: Move the journal coalgebra into holon-rs

**What:** Extract `Journal`, `Prediction`, `Outcome` (generalized to two-class labels), `observe`, `predict`, `decay` from `holon-lab-trading/src/journal.rs` into `holon-rs/src/memory/journal.rs`. Add `curve` as a method.

**Why this moves first:** The journal is the only core primitive without a runtime implementation. Every other core form already compiles to a holon-rs call. This is the single blocking gap for the core layer.

**The generalization:** The trading lab's `Journal` is already nearly domain-agnostic. It uses `Accumulator` (holon-rs kernel) and `Vector` (holon-rs kernel). The only domain-specific element is `Outcome::Buy | Sell | Noise`. The generalized form uses two-class labels (the journal is a binary discriminant) plus a noise/ignore option:

```rust
// holon-rs/src/memory/journal.rs
pub enum Label { A, B, Ignore }

pub struct Journal { ... }  // same internals as today

impl Journal {
    pub fn new(name: &str, dims: usize, recalib_interval: usize) -> Self;
    pub fn observe(&mut self, vec: &Vector, label: Label, weight: f64);
    pub fn predict(&self, vec: &Vector) -> Prediction;
    pub fn decay(&mut self, factor: f64);
    pub fn curve(&self, resolved: &[(Prediction, Label)]) -> (f64, f64);
}
```

The trading lab re-exports with domain aliases: `type Outcome = Label; const Buy: Label = Label::A;` etc.

**What does NOT move:** `decode_discriminant` (inspection utility), diagnostic fields (`last_cos_raw`, `last_disc_strength`). These are application concerns. They can access journal internals via a public `discriminant()` accessor.

**Deliverable:** `holon-rs/src/memory/journal.rs` exists. `holon-lab-trading/src/journal.rs` becomes a thin wrapper. All nine core forms compile to holon-rs calls.

### Phase 2: The compilation table

**What:** A document in `wat/docs/` that maps every wat form to its holon-rs implementation. One table per layer.

**Core forms:**

| wat form | holon-rs | module |
|----------|----------|--------|
| `(atom name)` | `VectorManager::get_vector(name)` | `kernel::vector_manager` |
| `(bind a b)` | `Primitives::bind(&a, &b)` | `kernel::primitives` |
| `(bundle a b ...)` | `Primitives::bundle(&[&a, &b, ...])` | `kernel::primitives` |
| `(cosine a b)` | `Similarity::cosine(&a, &b)` | `kernel::similarity` |
| `(journal name dims interval)` | `Journal::new(name, dims, interval)` | `memory::journal` |
| `(observe j thought label weight)` | `j.observe(&thought, label, weight)` | `memory::journal` |
| `(predict j thought)` | `j.predict(&thought)` | `memory::journal` |
| `(decay j rate)` | `j.decay(rate)` | `memory::journal` |
| `(curve j resolved)` | `j.curve(&resolved)` | `memory::journal` |

**Stdlib forms:**

| wat form | holon-rs | module |
|----------|----------|--------|
| `(permute v shift)` | `Primitives::permute(&v, shift)` | `kernel::primitives` |
| `(difference before after)` | `Primitives::difference(&before, &after)` | `kernel::primitives` |
| `(negate sup comp)` | `Primitives::negate(&sup, &comp)` | `kernel::primitives` |
| `(amplify sup comp str)` | `Primitives::amplify(&sup, &comp, str)` | `kernel::primitives` |
| `(prototype vecs threshold)` | `Primitives::prototype(&vecs, threshold)` | `kernel::primitives` |
| `(cleanup noisy codebook)` | `Primitives::cleanup(&noisy, &codebook)` | `kernel::primitives` |
| `(attend q mem str mode)` | `Primitives::attend(&q, &mem, str, mode)` | `kernel::primitives` |
| `(coherence vecs)` | `Primitives::coherence(&vecs)` | `kernel::primitives` |
| `(encode-log value)` | `ScalarEncoder::encode_log(value)` | `kernel::scalar` |
| `(encode-linear value scale)` | `ScalarEncoder::encode_linear(value, scale)` | `kernel::scalar` |
| `(encode-circular value period)` | `ScalarEncoder::encode_circular(value, period)` | `kernel::scalar` |
| `(online-subspace dims k)` | `OnlineSubspace::new(dims, k)` | `memory::subspace` |
| `(update sub vec)` | `sub.partial_fit(&vec)` | `memory::subspace` |
| `(residual sub vec)` | `sub.residual(&vec)` | `memory::subspace` |
| `(threshold sub)` | `sub.threshold()` | `memory::subspace` |

**Deliverable:** A single reference document. Every wat form has one row. A person can look up the Rust call without searching.

### Phase 3: Audit unnamed holon-rs operations

**What:** Review the ~30 `Primitives::*` methods that exist in holon-rs but have no wat form. For each, decide: stdlib candidate, or internal utility.

**Candidates likely to become stdlib forms:**
- `blend` — weighted interpolation. General-purpose. Used in memory systems.
- `prototype_add` — incremental prototype. General-purpose.
- `project` / `reject` — subspace projection. Used by memory layer.

**Candidates likely to remain unnamed utilities:**
- `grover_amplify` — quantum-inspired experiment. Niche.
- `random_project` — dimensionality reduction. Implementation detail.
- `similarity_matrix` — batch computation. Performance utility, not a new concept.
- `flip` — sign inversion. Trivially `(bind v (atom "negate"))` or similar.

**This is NOT urgent.** The unnamed operations work. Applications use them directly. The question is documentation and whether the wat stdlib should grow. This phase produces a list of recommendations, not code changes.

**Deliverable:** An appendix to the compilation table: "holon-rs operations without wat forms" with a disposition for each.

## 4. The Algebraic Question

**Does this change the algebra?** No. The five generators and nine forms remain identical. No new forms are proposed. The plan is about where implementations live (Phase 1), documentation (Phase 2), and future stdlib candidates (Phase 3).

**Does Phase 1 change the journal's algebraic properties?** No. The journal moves from application code to the runtime library. The API is identical. The internal algorithms are identical. The only change is generalized labels (A/B instead of Buy/Sell) — which is the correct generalization for a domain-agnostic primitive.

**Does Phase 3 risk bloating the stdlib?** It could, if the bar is low. The stdlib contract from Proposal 003 applies: a form enters stdlib only if it is (a) derivable from the core primitives and (b) useful across multiple domains. "Useful in one application" is not enough.

## 5. The Simplicity Question

**Is this simple or easy?**

Simple. Phase 1 moves code that is in the wrong layer to the right layer. Phase 2 writes down what is already true. Phase 3 names what is unnamed.

**What's being complected?**

Currently, "core primitive" and "application code" are complected in the journal. The journal is defined as core (Proposal 004) but implemented as application code (trading lab). A person reading the wat spec sees journal as foundational. A person reading holon-rs sees no journal. The map and the territory disagree.

**Could we skip Phase 1?**

Yes, if we accept that core primitives can live in application code and each application re-implements them. But this is exactly the problem that runtimes solve. If two applications need journals, they would each write their own, and the implementations would diverge. The primitive would fragment.

## 6. Questions for Designers

1. **Label generalization.** The trading lab uses Buy/Sell. The journal coalgebra is a binary discriminant. Should the holon-rs `Journal` use abstract labels (A/B), named string labels, or a generic type parameter `Journal<L: Label>`? The choice affects how applications alias the primitive.

2. **Curve placement.** `curve` fits a `accuracy = 0.50 + a * exp(b * conviction)` model to resolved predictions. This is more specific than observe/predict/decay. Should `curve` be a method on `Journal` in holon-rs, or should it remain a pattern that applications implement? The fitting algorithm itself is not algebraic — it is statistical.

3. **The threshold question for Phase 3.** What is the bar for a holon-rs operation to earn a wat stdlib form? Proposed: "used by two or more unrelated domains in practice." Is this the right threshold, or should it be stricter (algebraically derivable AND cross-domain)?

4. **Memory module scope.** Phase 1 puts Journal in `holon-rs/src/memory/`. Currently memory contains OnlineSubspace and Engram. After the move, memory would contain three learning primitives (Journal, OnlineSubspace, Engram). Is memory the right module, or should Journal get its own module given its coalgebra status?

5. **The compilation table format.** Phase 2 proposes a static document. An alternative: embed the mapping as doc comments in the wat files themselves (e.g., `;; compiles-to: Primitives::bind`). Which serves the reader better?
