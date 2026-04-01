# Resolution: ACCEPTED

Unanimous. Variadic update with parallel semantics.

```scheme
(update record :field1 value1 :field2 value2 :field3 value3)
```

All field expressions evaluate against the ORIGINAL record, not
intermediate state. If order matters, use `let` for genuine dependencies.

Core, not stdlib. This completes `update`, it doesn't extend it.
Same precedent as variadic `bundle`.
