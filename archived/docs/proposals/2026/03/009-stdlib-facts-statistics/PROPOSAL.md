# Proposal 009: Stdlib Fact Constructors and Statistics

**Scope:** structural — promoting proven userland forms to the wat stdlib.

## 1. The current state

The trading lab defines `fact/zone`, `fact/scalar`, `fact/comparison`, `fact/bare`, `mean`, `variance`, `stddev`, `skewness`, and `zero-vector` in `std-candidates.wat`. These forms passed all five wards (sever, reap, scry, gaze, forge). They are required by 16 files and used 100+ times.

They compose from existing primitives — no new algebra needed. Each is a `define` over `atom`, `bind`, `encode-linear`, `fold`, and host arithmetic.

## 2. The problem

These forms are defined in the application. Every wat program that encodes domain knowledge into vectors will reinvent them. A DDoS detector needs `(fact/zone "traffic" "spike")`. An MTG player needs `(fact/comparison "above" "creature-count" "threshold")`. Any streaming analytics system needs `mean` and `stddev`.

Without stdlib, every application writes its own `bind(atom("at"), bind(atom(indicator), atom(zone)))` and hopes it matches the same pattern.

## 3. The proposed change

### Fact constructors → `std/facts.wat`

```scheme
(define (fact/zone indicator zone)
  "This indicator is in this state."
  (bind (atom "at") (bind (atom indicator) (atom zone))))

(define (fact/comparison predicate a b)
  "A is above/below/crossing B."
  (bind (atom predicate) (bind (atom a) (atom b))))

(define (fact/scalar indicator value scale)
  "This indicator has this continuous value."
  (bind (atom indicator) (encode-linear value scale)))

(define (fact/bare label)
  "This named condition is present."
  (atom label))
```

Four named compositions of existing primitives. No new forms. No new syntax. Just `define` in the stdlib.

### Statistics → `std/statistics.wat`

```scheme
(define (mean xs)
  (if (empty? xs) 0.0
      (/ (fold + 0.0 xs) (len xs))))

(define (variance xs)
  (let ((m (mean xs)))
    (/ (fold (lambda (sum x) (+ sum (* (- x m) (- x m)))) 0.0 xs)
       (len xs))))

(define (stddev xs)
  (sqrt (variance xs)))

(define (skewness xs)
  (let ((m (mean xs)) (s (stddev xs)))
    (if (<= s 0.0) 0.0
        (/ (fold (lambda (sum x)
                   (+ sum (* (/ (- x m) s) (/ (- x m) s) (/ (- x m) s))))
                 0.0 xs)
           (len xs)))))
```

Pure arithmetic over lists. Empty-list guard at `mean` protects the chain.

## 4. The algebraic question

Fact constructors compose with the vector algebra — they produce Vectors via `bind` and `atom`. They are the standard interface between domain vocabulary and the algebra. Any program that encodes named knowledge uses these patterns.

Statistics do NOT compose with the algebra — they return Float, not Vector. They are pre-algebra helpers that produce values fed to `encode-linear` or `fact/scalar`. They sit below the algebra, not inside it.

Neither introduces new algebraic structure.

## 5. The simplicity question

**Fact constructors:** Four one-line `define`s. The simplest possible stdlib entry — named compositions of existing operations. Removing any one forces 10+ call sites to inline the bind pattern.

**Statistics:** Standard math. The alternative is every application defining its own `mean`. That's not simpler — it's duplicated.

## 6. The zero-vector question

`zero-vector` needs `dims` because vectors are fixed-dimensionality. But `(bundle)` with no args is the conceptual identity. Should the monoid identity be lazy — adopting dimensionality from context? If yes, `zero-vector` becomes `(bundle)` and needs no dims. If no, `zero-vector` needs a way to create a sized zero vector that the language currently doesn't provide.

## 7. Questions for designers

1. **Do fact constructors belong in stdlib?** They compose from existing primitives. Any domain needs them. 100+ usages in one application. The pattern is universal: domain knowledge → named vector encoding.

2. **Do statistics belong in stdlib?** `mean`, `variance`, `stddev` are standard math. Any analytical program needs them. They don't touch the algebra — they produce values the algebra consumes.

3. **Should `(bundle)` with no args be the lazy identity?** This would make `zero-vector` unnecessary as a stdlib form. The monoid identity adopts dimensionality from its first composition. Or does the identity need to know its size at creation?

4. **Bare strings in fact constructors.** `fact/zone` takes two strings where the domain has two distinct concepts (indicator vs zone). Should wat have tagged strings or newtypes? Or is the docstring sufficient?

5. **`std/facts.wat` and `std/statistics.wat` — or one file?** The concerns are distinct (encoding patterns vs numeric computation). Two files respects the separation.
