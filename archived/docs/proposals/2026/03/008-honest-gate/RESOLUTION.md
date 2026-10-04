# Resolution: ACCEPTED

Unanimous. The gaze found the crack. The forge proved it. The designers confirmed.

## The change

The gate splits into two honest functions:
- `opinion`: Prediction × Vector → Vector (domain-specific projection, lives in enterprise)
- `gate`: Vector × Vector × Bool → Vector (generic annotation, stays in stdlib)

The old gate hid a type boundary crossing. The new gate is Vector in, Vector out. The projection is named and visible.

## Where things live

- `std/patterns.wat`: the generic `gate` (annotate with credibility)
- `examples/enterprise.wat`: the domain-specific `opinion` (project Prediction → Vector)
- Call site: `(gate (opinion (predict jrnl thought) expert-atom) expert-atom proven?)`

Three composable arrows: `predict → opinion → gate`. Types close at every step.
