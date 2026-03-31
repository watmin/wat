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

Location: `~/work/holon/holon-lab-trading/wat/vocab/<name>.wat`

Vocabulary modules are APPLICATION concerns, not language concerns.
They live in the trading lab repo alongside the Rust implementation.

Define:
- **Atoms**: named concepts the module introduces
- **Facts**: what expressions the module produces (Zone, Comparison, Scalar, Bare)
- **Encoding rules**: which scalar encoder for each value type
- **Zone classifications**: threshold-based categories

```scheme
;; Example: vocab/oscillators.wat

(atom "williams-r")
(atom "williams-overbought")   ; zone: %R < -20
(atom "williams-oversold")     ; zone: %R > -80

;; Encoding: williams %R range [-100, 0] → normalize to [0, 1]
;; (bind williams-r (encode-linear (+ (/ wr 100) 1) 1.0))
;; Zone: (bind at (bind williams-r williams-overbought))
```

### 2. Implement in Rust

Location: `~/work/holon/holon-lab-trading/src/vocab/<name>.rs`

Structure:
```rust
//! vocab/<name> — description
//! Spec: ~/work/holon/holon-lab-trading/wat/vocab/<name>.wat

use crate::vocab::Fact;

/// Pure computation. Returns facts, not vectors.
/// The encoder renders facts to geometry. Modules return data.
pub fn eval(candles: &[Candle]) -> Vec<Fact> { ... }
```

Rules:
- Pure functions. No state. No side effects.
- Takes `&[Candle]` window, returns `Vec<Fact>`.
- The Fact interface: modules return data, the encoder renders to geometry.
- Zone classification at threshold boundaries.

### 3. Register the module

In `src/vocab/mod.rs`:
```rust
pub mod oscillators;
pub mod flow;
pub mod new_module;  // add here
```

### 4. Add atoms to ThoughtVocab

In `src/thought/mod.rs`, find `INDICATOR_ATOMS` and `ZONE_ATOMS`:
```rust
const INDICATOR_ATOMS: &[&str] = &[
    // ... existing ...
    // vocab/new_module
    "new-atom-1", "new-atom-2",
];
```

### 5. Wire into expert dispatch

In `src/thought/mod.rs`, find the expert's exclusive section:
```rust
if is(&["target_expert"]) {
    self.encode_facts(&crate::vocab::new_module::eval(candles), ...);
}
```

### 6. Run and measure

```bash
./enterprise.sh test 100000 --asset-mode hold --swap-fee 0.0010 \
  --slippage 0.0025 --name new-module-100k
```

Check: did the expert's gate open more often? Did direction accuracy improve?

### 7. Update wat spec with findings

Append a DISCOVERY or RESOLVED section to the module's wat spec.

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
Comparisons are shared by momentum and structure only.

| Expert | Modules |
|---|---|
| Momentum | oscillators, divergence, stochastic, momentum (CCI/ROC) |
| Structure | segments, levels, ichimoku, fibonacci, keltner, timeframe |
| Volume | flow, participation, price action |
| Narrative | temporal, calendar, timeframe narrative |
| Regime | persistence, complexity, microstructure |
| Generalist | all of the above (profile "full", fixed window) |

To move a module between experts: update the `is(&[...])` dispatch
in thought/mod.rs and the eval methods list in the observer's wat spec.
