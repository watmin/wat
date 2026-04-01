# Wat → Rust Compilation Guide

Wat specifies. Rust implements. This document maps wat forms to their
Rust compilation targets. Not a compiler spec — a guide for the human
who reads wat and writes Rust.

## Literals

| Wat | Rust |
|-----|------|
| `true` / `false` | `bool` |
| `0`, `1.5`, `-3` | `f64` (all numbers are f64) |
| `"hello"` | `&str` or `String` |

There is no `nil`. Absence is structural — see Optionality below.

## Arithmetic

Wat arithmetic maps directly:

| Wat | Rust |
|-----|------|
| `(+ a b)` | `a + b` |
| `(abs x)` | `x.abs()` |
| `(sqrt x)` | `x.sqrt()` |
| `(clamp x lo hi)` | `x.clamp(lo, hi)` |
| `(exp x)` | `x.exp()` |
| `(ln x)` | `x.ln()` |
| `(max a b)` | `a.max(b)` |
| `(min a b)` | `a.min(b)` |
| `(mod a b)` | `a % b` |
| `(signum x)` | `x.signum()` |

## Comparison and Logic

| Wat | Rust |
|-----|------|
| `(= a b)` | `a == b` |
| `(!= a b)` | `a != b` |
| `(> a b)` | `a > b` |
| `(and x y)` | `x && y` |
| `(or x y)` | `x \|\| y` |
| `(not x)` | `!x` |

## Control Flow

| Wat | Rust |
|-----|------|
| `(if cond then else)` | `if cond { then } else { else }` |
| `(when cond body)` | `if cond { Some(body) }` or `if cond { body }` — see Optionality |
| `(when-let ((x expr)) body)` | `if let Some(x) = expr { body }` |
| `(cond (c1 e1) (c2 e2) (else e3))` | `if c1 { e1 } else if c2 { e2 } else { e3 }` |
| `(cond (c1 e1) (c2 e2))` | `if c1 { Some(e1) } else if c2 { Some(e2) } else { None }` — no else = optional |
| `(match x :a ea :b eb)` | `match x { A => ea, B => eb }` |
| `(let ((a 1) (b 2)) body)` | `{ let a = 1; let b = 2; body }` |
| `(let* ((a 1) (b a)) body)` | `{ let a = 1; let b = a; body }` — sequential |
| `(lambda (x) body)` | `\|x\| body` or `fn(x) -> T { body }` |

## Optionality (structural absence)

Wat has no nil. Absence is expressed by control flow, not values.
The compiler infers `Option<T>` from structure:

| Wat pattern | Rust return type |
|-------------|-----------------|
| `(when cond body)` as function body | `Option<T>` — None when cond is false |
| `(cond ...` without else) as function body | `Option<T>` — None when no branch matches |
| `(when-let ((x expr)) body)` | `if let Some(x) = expr { Some(body) } else { None }` |
| Direct expression as function body | `T` — always returns |

Struct fields ending in `?` are optional:

```scheme
(struct side-state latest? age staleness)
```

```rust
struct SideState {
    latest: Option<Candle>,  // ? suffix → Option
    age: usize,
    staleness: usize,
}
```

When a `?` field is not provided in the constructor, it initializes to `None`.

## Structs

| Wat | Rust |
|-----|------|
| `(struct name f1 f2)` | `pub struct Name { pub f1: T, pub f2: T }` |
| `(name :f1 v1 :f2 v2)` | `Name { f1: v1, f2: v2 }` — construction |
| `(:f1 record)` | `record.f1` — field access |
| `(update record :f1 v1 :f2 v2)` | `Name { f1: v1, f2: v2, ..record }` — parallel semantics |

## Protocols

| Wat | Rust |
|-----|------|
| `(defprotocol indicator (step [state input]))` | `trait Indicator { fn step(&self, input: f64) -> (Self, f64); }` |
| `(satisfies sma-state indicator :step sma-step)` | `impl Indicator for SmaState { fn step(&self, input: f64) -> ... { sma_step(self, input) } }` |

Protocols are check-only in wat — no dispatch. The forge verifies the named
function exists with correct arity. The Rust compiler enforces the full trait.

## Enums

| Wat | Rust |
|-----|------|
| `(enum dir :long :short)` | `enum Dir { Long, Short }` |
| `(match x :long el :short es)` | `match x { Dir::Long => el, Dir::Short => es }` |
| Exhaustive — every variant handled | Compiler enforces |

## Iteration

| Wat | Rust |
|-----|------|
| `(map f xs)` | `xs.iter().map(f).collect()` |
| `(filter f xs)` | `xs.iter().filter(f).collect()` |
| `(filter-map f xs)` | `xs.iter().filter_map(f).collect()` |
| `(fold f init xs)` | `xs.iter().fold(init, f)` |
| `(fold-left f init xs)` | same — left fold is default |
| `(for-each f xs)` | `for x in &xs { f(x); }` |
| `(count f xs)` | `xs.iter().filter(f).count()` |
| `(range a b)` | `(a..b)` |

## Collections

| Wat | Rust |
|-----|------|
| `(list a b c)` | `vec![a, b, c]` |
| `(len xs)` | `xs.len()` |
| `(nth xs i)` | `xs[i]` |
| `(first xs)` | `xs[0]` or `xs.first()` |
| `(rest xs)` | `&xs[1..]` |
| `(last xs)` | `xs.last().unwrap()` |
| `(last-n xs n)` | `&xs[xs.len().saturating_sub(n)..]` |
| `(take xs n)` | `&xs[..n]` |
| `(append xs ys)` | `[xs, ys].concat()` or `extend` |
| `(reverse xs)` | `xs.iter().rev().collect()` |
| `(sort-by f xs)` | `xs.sort_by(f)` |
| `(empty? xs)` | `xs.is_empty()` |
| `(zeros n)` | `vec![0.0; n]` |

## Maps

| Wat | Rust |
|-----|------|
| `{}` | `HashMap::new()` |
| `(get m k)` | `m.get(&k)` |
| `(get m k default)` | `m.get(&k).copied().unwrap_or(default)` |
| `(assoc m k v)` | `m.insert(k, v); m` — sequential for variadic |
| `(keys m)` | `m.keys()` |

## Queues

| Wat | Rust |
|-----|------|
| `(deque)` | `VecDeque::new()` |
| `(push-back q v)` | `q.push_back(v)` |
| `(pop-front q)` | `q.pop_front()` |

## Mutation

| Wat | Rust |
|-----|------|
| `(set! (:field record) value)` | `record.field = value;` — requires `&mut self` |
| `(push! vec value)` | `vec.push(value);` |
| `(pop! vec)` | `vec.pop();` |
| `(inc! (:field record))` | `record.field += 1;` |

These map to `&mut self` in Rust. Honest about mutation.

## The Two Algebras

### Vector algebra

| Wat | Rust |
|-----|------|
| `(atom name)` | `vm.get_vector(name)` — deterministic, cached |
| `(bind a b)` | `Primitives::bind(&a, &b)` |
| `(bundle vs)` | `Primitives::bundle(&refs)` |
| `(cosine a b)` | `Similarity::cosine(&a, &b)` |
| `(difference a b)` | `Primitives::difference(&a, &b)` |
| `(encode-linear v s)` | `scalar.encode(v, ScalarMode::Linear { scale: s })` |
| `(encode-log v)` | `scalar.encode_log(v)` |
| `(encode-circular v p)` | `scalar.encode(v, ScalarMode::Circular { period: p })` |

### Journal coalgebra

| Wat | Rust |
|-----|------|
| `(journal name dims interval)` | `Journal::new(name, dims, interval)` |
| `(register journal name)` | `journal.register(name)` → `Label` |
| `(observe journal thought label weight)` | `journal.observe(&thought, label, weight)` |
| `(predict journal thought)` | `journal.predict(&thought)` → `Prediction` |
| `(decay journal rate)` | `journal.decay(rate)` |
| `(recalib-count journal)` | `journal.recalib_count()` → `usize` |
| `(discriminant journal label)` | `journal.discriminant(label)` → `Option<&[f64]>` |
| `(resolve journal conviction correct)` | `journal.resolve(conviction, correct)` |
| `(curve journal)` | `journal.curve()` → `(f64, f64)` |

### Memory (OnlineSubspace)

| Wat | Rust |
|-----|------|
| `(online-subspace dims k)` | `OnlineSubspace::new(dims, k)` |
| `(update subspace vector)` | `subspace.update(&vector)` |
| `(residual subspace vector)` | `subspace.residual(&vector)` → `f64` |
| `(threshold subspace)` | `subspace.threshold()` → `f64` |

## Naming conventions

| Wat | Rust |
|-----|------|
| `kebab-case` | `snake_case` |
| `:keyword` | field access: `record.field` |
| `name?` predicate | `is_name()` or `name` returning bool |
| `field?` on struct | `Option<T>` field |
| `set!` / `push!` / `inc!` | `&mut self` methods |
