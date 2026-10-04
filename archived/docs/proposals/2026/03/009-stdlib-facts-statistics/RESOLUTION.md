# Resolution: ACCEPTED

Unanimous. Both designers approved. No tensions.

## The promotion

Two new stdlib files:
- `std/facts.wat` — fact/zone, fact/comparison, fact/scalar, fact/bare
- `std/statistics.wat` — mean, variance, stddev, skewness

`zero-vector` stays in the application with explicit `dims`. The monoid identity is not lazy — a value knows its size at creation.

No tagged strings. No newtypes. The docstring guards. The wards catch structural misuse. The curve catches semantic misuse.

## Evidence

- Defined in userland, passed all 5 wards
- 16 files depend on them, 100+ usages
- Dissolves 30 phantom runes on promotion
- Both designers confirmed: these are universal, not domain-specific
