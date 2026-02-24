# Modernization Handoff (Resume Guide)

This document is the canonical handoff state for continuing the Ruby 3.2+/3.3+ modernization in a new conversation.

## Snapshot

- Snapshot date: 2026-02-22
- Active branch: `codex/experiment-ruby3-modernization`
- Branch head at snapshot: `61d61e8` (pre-Phase 5A release automation implementation)
- Repo status at snapshot: clean working tree

## Project Goal

Modernize `lda-ruby` for Ruby 3.2+/3.3+ with:

- stable Ruby API compatibility
- high-performance Rust backend for hot paths
- pure Ruby fallback for portability
- reliable packaging and release validation

## Current Backend Behavior

- `auto` selection order: `rust` -> `native` -> `pure_ruby`
- `LDA_RUBY_BACKEND` override supported for `rust`, `native`, and `pure`
- Rust build policy for source installs: `LDA_RUBY_RUST_BUILD=auto|always|never`

## Phase Status

### Phase 1 (API/tests stabilization)

Status: complete.

Delivered:

- expanded compatibility fixtures
- CI test coverage for multiple backend modes

### Phase 2 (backend boundary extraction)

Status: complete.

Delivered:

- `Lda::Lda` delegates through backend adapters
- backend selection normalized through `Lda::Backends.build`

### Phase 3 (pure Ruby reference backend)

Status: complete.

Delivered:

- full pure Ruby backend path with EM/model outputs
- pure backend compatibility in tests

### Phase 4 (Rust native backend)

Status: mostly complete.

Delivered:

- Rust extension scaffold with magnus/rb_sys
- Rust kernels for the main hot loops:
  - corpus iteration
  - document inference
  - topic weights
  - topic-term accumulation
  - topic-term finalization (`beta`/`log(beta)`)
  - gamma shift reduction
  - topic-document probability
  - seeded initialization
- trusted kernel-output fast path enabled in rust mode
- parity/compatibility test coverage and rust runtime CI

Open in Phase 4:

- optional deeper Rust ownership of orchestration logic (current design still intentionally delegates control flow through Ruby fallback scaffolding)

### Phase 5 (packaging/release)

Status: Phase 5A complete (source-gem release automation), Phase 5B pending.

Delivered:

- clean gem file filtering (no local cargo/native artifacts)
- Docker install-policy matrix checks
- packaged gem runtime checks without Cargo (`bin/test-packaged-gem-fallback`)
- packaged gem runtime checks with Cargo (`bin/test-packaged-gem-rust-enabled`)
- packaged gem manifest/metadata gate (`bin/test-packaged-gem-manifest`)
- single-command local gate (`bin/release-preflight`)
- version/tag parity guard (`bin/check-version-sync`)
- deterministic release preparation helper (`bin/release-prepare`)
- release artifact builder with checksum output (`bin/release-artifacts`)
- tag-driven release workflow (`.github/workflows/release.yml`)
- maintainer release runbook (`docs/release-runbook.md`)
- CI jobs for packaged-gem fallback, rust-enabled checks, and manifest checks

Open in Phase 5:

- native/precompiled gem publishing workflow is not implemented yet (Phase 5B)
- platform strategy (initial Linux/macOS target matrix, packaging format, and rollout guardrails) still needs implementation

## Validation Commands

Core:

- `./bin/docker-test`
- `./bin/docker-test-rust`

Packaging/release checks:

- `./bin/check-version-sync`
- `./bin/test-packaged-gem-manifest`
- `./bin/test-packaged-gem-fallback`
- `./bin/test-packaged-gem-rust-enabled`
- `SKIP_DOCKER=1 ./bin/release-preflight`
- `./bin/release-artifacts --tag v0.4.0`

Optional full Docker matrix:

- `./bin/docker-test-install-policies`

Performance tracking:

- `./bin/benchmark-backends`

## CI Jobs Expected

- native tests (`test-native`)
- pure backend tests (`test-pure`)
- rust runtime tests (`rust-runtime`)
- Docker install policy matrix (`install-policy-matrix`)
- packaged gem fallback checks (`packaged-gem-fallback`)
- packaged gem rust-enabled checks (`packaged-gem-rust-enabled`)
- packaged gem manifest checks (`packaged-gem-manifest`)
- rust scaffold check (`rust-scaffold`)
- release validation/build/publish pipeline on `v*` tags (`release.yml`)

## Remaining Work Queue

Priority 1:

- implement Phase 5B native/precompiled gem build+publish pipeline (initial Linux/macOS targets)
- define publish artifact strategy (single platform gems vs. split package set) and compatibility policy

Priority 2:

- decide whether to keep current hybrid rust-kernel architecture or move more orchestration into Rust
- if moving deeper into Rust, define parity guardrails and benchmark thresholds before refactors

Priority 3:

- extend release runbook with Phase 5B precompiled-gem troubleshooting once packaging strategy lands

## Resume Instructions For A New Conversation

1. Check out `codex/experiment-ruby3-modernization`.
2. Open this file first: `docs/modernization-handoff.md`.
3. Run `SKIP_DOCKER=1 ./bin/release-preflight`.
4. Review `docs/release-runbook.md` for release flow/rollback details.
5. Continue with `Priority 1` items under "Remaining Work Queue" (Phase 5B precompiled gems).

If you want the next assistant to continue immediately, use:

"Open `docs/modernization-handoff.md`, validate with `SKIP_DOCKER=1 ./bin/release-preflight`, and start implementing Phase 5B precompiled gem packaging."
