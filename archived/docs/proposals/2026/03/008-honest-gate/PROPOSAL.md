# Proposal 008: Honest Gate

**Scope:** structural — fixing a type boundary violation in `std/patterns.wat`.

**Origin:** The gaze found a name hiding a transformation. The forge proved the types don't close. The Rust implementation already has the honest version.

## 1. The current state

The gate pattern in `std/patterns.wat`:

```scheme
(define (gate journal thought proven?)
  (let ((prediction (predict journal thought))
        (status (if proven? (atom "proven") (atom "tentative"))))
    (bundle prediction (bind (atom "credibility") status))))
```

`predict` returns a `Prediction` — a struct with `{ scores, direction, conviction, raw-cosine }`. `bundle` takes Vectors. The function bundles a Prediction into a Vector operation.

## 2. The problem

`Prediction` is not a `Vector`. The bundle operation is algebraically undefined here. The types don't close.

The Rust implementation (`market/manager.rs:86-95`) never bundles a Prediction. It:
1. Extracts `raw-cosine` from the Prediction
2. Encodes magnitude as a scalar vector
3. Selects direction atom (buy/sell) from the sign
4. Binds expert identity to direction+magnitude → opinion Vector
5. Separately binds expert identity to proven/tentative → credibility Vector

The Rust projects before it bundles. The wat hides the projection behind a name.

## 3. The proposed change

Split the gate into two honest functions:

```scheme
;; Project: Prediction → Vector
;; The lossy, domain-specific step. Extracts direction and magnitude
;; from a Prediction struct and binds them to an expert identity.
(define (opinion prediction expert-atom)
  (let ((direction (if (>= (:raw-cosine prediction) 0) (atom "buy") (atom "sell")))
        (magnitude (encode-linear (abs (:raw-cosine prediction)) 1.0)))
    (bind expert-atom (bind direction magnitude))))

;; Gate: Vector → Vector (annotate with credibility)
;; Takes an opinion vector (already projected) and bundles it
;; with a credibility annotation. Types close: Vector in, Vector out.
(define (gate opinion-vector expert-atom proven?)
  (let ((status (if proven? (atom "proven") (atom "tentative"))))
    (bundle opinion-vector (bind expert-atom status))))
```

The gate becomes simpler — it annotates, it doesn't project. The `opinion` function does the projection. Both are honest about their types.

The enterprise.wat call site becomes:

```scheme
;; Before: gate hides the projection
(gate jrnl thought (curve-valid? jrnl))

;; After: projection is visible
(let ((opinion-vec (opinion (predict jrnl thought) expert-atom)))
  (gate opinion-vec expert-atom (curve-valid? jrnl)))
```

## 4. The algebraic question

Does the split compose?

- `predict`: `Journal × Vector → Prediction` (coalgebra observation)
- `opinion`: `Prediction × Vector → Vector` (projection + encoding)
- `gate`: `Vector × Vector × Bool → Vector` (annotation)

Each step's output matches the next step's input. The types close. The composition is: `gate ∘ opinion ∘ predict`. The caller can compose all three or use each independently.

The old gate was: `gate: Journal × Vector × Bool → Vector` with a hidden `predict ∘ project` inside. The caller couldn't use the prediction without the annotation, or the annotation without the projection.

## 5. The simplicity question

The old gate was one function doing three things: predict, project, annotate. The new gate does one thing: annotate. The `opinion` function does one thing: project. `predict` already does one thing: observe.

Three functions, each doing one thing, composable in any combination. vs. One function doing three things, take it or leave it.

## 6. Questions for designers

1. **Does `opinion` belong in stdlib or in the enterprise example?** It's domain-specific (it knows about buy/sell atoms, linear encoding). The gate itself is domain-agnostic (it just bundles with a credibility tag). Should `opinion` be an enterprise function that calls a generic `gate`?

2. **Does the gate still belong in `std/patterns.wat`?** If the gate is just `(bundle vec (bind expert-atom status))`, is it worth naming as a pattern? Or is it simple enough to inline?

3. **Should `opinion` use the struct projection syntax?** The proposal uses `(:raw-cosine prediction)` — the keyword-as-function syntax from proposal 007. This is the first stdlib function to use the struct projection. Does it demonstrate the syntax well?
