# Contributing to Wat Programs

## The Cycle

```
wat spec (what to think)
    → Rust impl (how to compute it)
        → wire into expert dispatch (who thinks it)
            → run (does it improve accuracy?)
                → DB analysis (what happened?)
                    → update wat spec (what did we learn?)
```

## Adding a Vocabulary Module

### 1. Write the wat spec

Location: `~/work/holon/wat/mod/<name>.wat`

Define:
- **Atoms**: named concepts the module introduces
- **Facts**: what expressions the module produces
- **Encoding rules**: which scalar encoder for each value type
- **Zone classifications**: threshold-based categories

```scheme
;; Example: mod/oscillators.wat

(atom "williams-r")
(atom "williams-overbought")   ; zone: %R < -20
(atom "williams-oversold")     ; zone: %R > -80

;; Encoding: williams %R range [-100, 0] → normalize to [0, 1]
;; (bind williams-r (encode-linear (+ (/ wr 100) 1) 1.0))
;; Zone: (bind at (bind williams-r williams-overbought))
```

### 2. Implement in Rust

Location: `~/work/holon/holon-lab-trading/rust/src/vocab/<name>.rs`

Structure:
```rust
//! mod/<name> — description
//! Spec: ~/work/holon/wat/mod/<name>.wat

use crate::db::Candle;

/// Pure computation from candle data. No holon imports needed.
pub fn compute_indicator(candles: &[Candle]) -> Option<f64> { ... }

/// All facts for this module.
pub struct ModuleFacts {
    pub value: Option<f64>,
    pub zone: Option<&'static str>,
    // ...
}

pub fn eval_module(candles: &[Candle]) -> ModuleFacts { ... }
```

Rules:
- Pure functions. No state. No side effects.
- Takes `&[Candle]` window, returns computed values.
- Zone classification at threshold boundaries.
- The struct collects all facts for the caller to encode.

### 3. Register the module

In `rust/src/vocab/mod.rs`:
```rust
pub mod oscillators;
pub mod flow;
pub mod new_module;  // add here
```

### 4. Add atoms to ThoughtVocab

In `rust/src/thought.rs`, find `INDICATOR_ATOMS` and `ZONE_ATOMS`:
```rust
const INDICATOR_ATOMS: &[&str] = &[
    // ... existing ...
    // vocab/new_module
    "new-atom-1", "new-atom-2",
];

const ZONE_ATOMS: &[&str] = &[
    // ... existing ...
    // vocab/new_module zones
    "new-zone-1", "new-zone-2",
];
```

### 5. Wire into expert dispatch

In `rust/src/thought.rs`, find the expert's exclusive section:
```rust
if is(&["target_expert"]) {
    // ... existing eval methods ...
    self.eval_new_module(candles, &mut owned_facts, &mut labels);
}
```

### 6. Write the eval method

In `rust/src/thought.rs`, add the method to `ThoughtEncoder`:
```rust
fn eval_new_module(
    &self,
    candles: &[Candle],
    facts: &mut Vec<Vector>,
    labels: &mut Vec<String>,
) {
    use crate::vocab::new_module::eval_module;
    let result = eval_module(candles);

    // Zone facts: binary (present when in zone)
    if let Some(zone) = result.zone {
        let fact = Primitives::bind(self.vocab.get("at"),
            &Primitives::bind(self.vocab.get("indicator"), self.vocab.get(zone)));
        facts.push(fact);
        labels.push(format!("(at indicator {})", zone));
    }

    // Scalar facts: continuous value
    if let Some(value) = result.value {
        let v = self.scalar_enc.encode(
            value.clamp(0.0, 1.0),        // normalize to [0, 1]
            ScalarMode::Linear { scale: 1.0 }  // theoretical range
        );
        facts.push(Primitives::bind(self.vocab.get("indicator"), &v));
        labels.push(format!("(indicator {:.3})", value));
    }
}
```

### 7. Run and measure

```bash
./trader.sh test3 50000 --orchestration thought-only --flip-quantile 0.99 \
  --dims 20000 --sizing kelly --swap-fee 0.0010 --slippage 0.0025 \
  --asset-mode hold --name new-module-50k
```

Check: did the expert's gate open more often? Did direction accuracy improve?

```sql
SELECT conviction_bucket, accuracy FROM candle_log ...
```

### 8. Update wat spec with findings

Append to `~/work/holon/holon-lab-trading/wat/DISCOVERIES.md`.

---

## Encoding Rules

Every value has a nature. The encoder matches the nature.

| Value nature | Encoder | Scale | Example |
|---|---|---|---|
| Fraction [0, 1] | `encode-linear` | 1.0 | accuracy, ratio, normalized |
| Bounded range | `encode-linear` | 1.0 | after normalizing to [0, 1] |
| Orders of magnitude | `encode-log` | — | ATR, volume, tenure |
| Periodic/cyclical | `encode-circular` | period | hour (24), day (7) |
| Named category | atom lookup | — | session, zone name |
| Below 3/√dims | silence | — | noise floor |

Never use empirical scales. Always use theoretical range.

---

## Expert Assignment

Each module belongs to exactly one expert (exclusive vocabulary).
The stdlib comparisons are shared across all experts.

| Expert | Modules |
|---|---|
| Momentum | oscillators, divergence, crosses |
| Structure | segments, levels, channels |
| Volume | flow, participation |
| Narrative | temporal, calendar |
| Regime | persistence, complexity, microstructure |

To move a module between experts: update the `is(&[...])` dispatch
in thought.rs and the `(require ...)` in the expert's wat spec.
