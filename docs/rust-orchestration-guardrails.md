# Rust Orchestration Guardrails

This document defines the minimum parity and performance gates for deeper Rust orchestration refactors.

## Numeric parity guardrails

Required tests:

- `bundle exec ruby -Ilib:test test/backend_compatibility_test.rb`
- `bundle exec ruby -Ilib:test test/rust_orchestration_test.rb`

Current parity expectations:

- Rust vs pure backend fixture parity remains exact within existing tolerances used by tests.
- Session-based orchestration paths (`run_em_on_session_with_start_seed`, `run_em_on_session_start`) must match direct non-session orchestration for equivalent settings/seeds.
- Rust backend corpus/session lifecycle must not leak session count across corpus replacement.

## Benchmark guardrail

Run:

- `./bin/check-rust-benchmark`

Default benchmark policy:

- `BENCH_RUST_TO_PURE_MAX_RATIO=0.75`
  - i.e., Rust mean runtime must be no worse than 75% of pure mean runtime on the benchmark fixture/config.
- CI benchmark guardrail job enforces the same ratio with `BENCH_RUNS=1` for runtime stability.

Configurable environment knobs:

- `BENCH_RUNS` (default `5`)
- `BENCH_START` (default `seeded`)
- `BENCH_TOPICS` (default `8`)
- `BENCH_MAX_ITER` (default `20`)
- `BENCH_EM_MAX_ITER` (default `40`)
- `BENCH_RUST_TO_PURE_MAX_RATIO` (default `0.75`)

## When to tighten thresholds

Tighten benchmark thresholds only after collecting multiple stable runs on the same host/environment and updating this document with the new target ratio.
