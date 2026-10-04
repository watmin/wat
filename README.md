# wat

A Lisp for Linux programming, compiled to native x86-64 code. It aims to meet or beat C's performance, and to always
beat Rust's.

> *"its a lisp for linux programming... (maybe more OS later... linux for now)... like c is .... i want watc to emit
> code that meets or exceeds c's perf (always better than rust's perf)"* — the builder, 2026-10-03

wat started as two things: a way for LLMs to *think in Lisp*, so that a thought can be evaluated, and a Lisp that feels
like Clojure but is built for LLMs to operate on at system speed. Fully qualified names everywhere are one property of
that.

## What this repository is now

The home of the native, Rust-free wat:
- **watc**, the compiler, which compiles itself;
- **the bootstrap ladder** that builds it from source with no binary taken on faith. A hand-auditable seed comes
  first, then an assembler, then a minimal interpreter for the subset watc is written in. That interpreter runs
  watc's source once, and from there watc rebuilds itself.

The work starts at the bottom of that ladder.

## Lineage

- **2024**, "OG wat": an English-like, strongly typed Lisp. Its spec and Ruby reference live in
  [watmin/scratch](https://github.com/watmin/scratch), `2026/05/002-og-wat-lineage/`.
- **2026**, an s-expression language for algebraic cognition, implemented in Rust:
  [watmin/wat-rs](https://github.com/watmin/wat-rs). That era's contents of this repository are preserved under
  [`archived/`](archived/).
- **2026-09**: watc, a self-hosting compiler written in wat, emitting x86-64 ELF. It was grown in
  [watmin/the-little-wat](https://github.com/watmin/the-little-wat), and it is what this repository builds from here on.

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
