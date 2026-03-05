# Rust Orchestration Guardrails

This document defines the minimum parity and performance gates for deeper Rust orchestration refactors.

## Numeric parity guardrails

Required tests:

- `bundle exec ruby -Ilib:test test/backend_compatibility_test.rb`
- `bundle exec ruby -Ilib:test test/rust_orchestration_test.rb`

Current parity expectations:

- Rust vs pure backend fixture parity remains exact within existing tolerances used by tests.
- Session-based orchestration paths (`run_em_on_session`, `run_em_on_session_with_start_seed`, `run_em_on_session_start`, `run_em_on_session_with_corpus`) must match direct non-session orchestration for equivalent settings/seeds.
- `Lda::Backends::Rust` non-session fallback should prefer Rust start-aware orchestration (`run_em_with_start_seed`) before legacy beta-input orchestration (`run_em`).
- Rust backend corpus/session lifecycle must not leak session count across corpus replacement.
- Missing-session recovery in managed session orchestration (`run_em_on_session_with_corpus`) must recreate a usable session and keep parity with direct orchestration.
- Corpus reassignment through Rust session replacement lifecycle (`replace_corpus_session`) must preserve stable session count and route subsequent EM runs over updated corpus data.
- Unknown start-mode handling in seed-aware Rust orchestration must match Ruby's non-seeded fallback behavior when given the same explicit seed.

## Benchmark guardrail

Run:

- `./bin/check-rust-benchmark`

Default benchmark policy:

- `BENCH_RUST_TO_PURE_MAX_RATIO=0.045`
  - i.e., Rust mean runtime must be no worse than 4.5% of pure mean runtime on the benchmark fixture/config.
- CI benchmark guardrail job enforces the same ratio with `BENCH_RUNS=1` for runtime stability.
- latest tightening evidence (2026-03-05): local Docker guardrail check with `BENCH_RUNS=3` observed Rust/Pure ratio `0.0368` (`rust=0.0758s`, `pure=2.0569s`), and prior CI streak data on `codex/rust-orchestration-phase8` (`22555725309` .. `22557953998`) observed `[0.0252, 0.0288]`, supporting a tighter `0.045` threshold with headroom.

Configurable environment knobs:

- `BENCH_RUNS` (default `5`)
- `BENCH_START` (default `seeded`)
- `BENCH_TOPICS` (default `8`)
- `BENCH_MAX_ITER` (default `20`)
- `BENCH_EM_MAX_ITER` (default `40`)
- `BENCH_RUST_TO_PURE_MAX_RATIO` (default `0.045`)

## When to tighten thresholds

Tighten benchmark thresholds only after collecting multiple stable runs on the same host/environment and updating this document with the new target ratio.
