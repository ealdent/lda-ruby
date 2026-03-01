# Modernization Handoff (Resume Guide)

This document is the canonical handoff state for continuing the Ruby 3.2+/3.3+ modernization in a new conversation.

## Snapshot

- Snapshot date: 2026-02-25
- Active branch: `master`
- Repo status at snapshot start: clean working tree on `master` (in sync with `origin/master`)
- Modernization branch: `codex/modernization` merged into `master`
- Merge commit for modernization PR: `bc11269` (`Merge pull request #18 from ealdent/codex/modernization`)
- Latest release dry-run validation (GitHub Actions):
  - date: 2026-02-25
  - workflow run: `release.yml` run `22382692416` (`workflow_dispatch`, `publish=false`)
  - result: success (`validate release candidate`, `build release artifacts`, and all `build precompiled artifacts` matrix targets)
  - publish jobs skipped by design (`publish=false`)
- Modernization pull request:
  - PR `#18`: `https://github.com/ealdent/lda-ruby/pull/18`
  - state: merged (2026-02-25)
- Release publish attempts (`v0.4.0`):
  - `release.yml` run `22383716372`: failed at RubyGems publish (`No such API key`)
  - `release.yml` run `22383849236`: failed at RubyGems publish (`OTP code required`)
  - rerun attempt (`22383849236`, attempt 2): failed at RubyGems publish (`OTP code required`)
  - rerun attempt (`22383849236`, attempt 3): success (RubyGems publish + GitHub release publish complete)
- Release status:
  - `v0.4.0` published to RubyGems (source + precompiled Linux/macOS gems)
  - GitHub release `v0.4.0` published with gem + `.sha256` assets

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
- Rust-side EM orchestration path (`Lda::RustBackend.run_em`) with deterministic Ruby fallback reuse via precomputed EM inputs
- Rust-side start-aware deterministic orchestration path (`Lda::RustBackend.run_em_with_start`) for `seeded`/`deterministic` EM starts, with random-start compatibility retained via Ruby-initialized fallback path
- Rust-side random-start orchestration path (`Lda::RustBackend.run_em_with_start_seed`) using explicit seed-controlled random initialization (`Lda::RustBackend.random_topic_term_probabilities`)
- Rust-managed corpus session lifecycle (`Lda::RustBackend.create_corpus_session` / `drop_corpus_session`) with session-based start-aware EM orchestration (`run_em_on_session_with_start_seed`) wired in `Lda::Backends::Rust`
- Rust-managed session settings lifecycle (`configure_corpus_session`) with settings-aware orchestration (`run_em_on_session_start`) wired in `Lda::Backends::Rust`
- Rust session execution refactor to shared session corpus storage + borrowed orchestration helpers, eliminating deep corpus clone overhead on each session EM run
- unified Rust session orchestration API (`run_em_on_session`) that applies settings + runs EM in one call, now preferred by `Lda::Backends::Rust`
- `Lda::Backends::Rust` now re-registers missing Rust corpus sessions before EM to preserve session-based orchestration when sessions are dropped externally
- parity/compatibility test coverage and rust runtime CI

Open in Phase 4:

- optional deeper Rust ownership beyond current unified session orchestration (for example additional control-plane logic and lifecycle APIs)

### Phase 5 (packaging/release)

Status: Phase 5A complete (source-gem release automation), Phase 5B complete for initial Linux/macOS precompiled gems.

Delivered:

- clean gem file filtering (no local cargo/native artifacts)
- Docker install-policy matrix checks
- packaged gem runtime checks without Cargo (`bin/test-packaged-gem-fallback`)
- packaged gem runtime checks with Cargo (`bin/test-packaged-gem-rust-enabled`)
- packaged gem manifest/metadata gate (`bin/test-packaged-gem-manifest`)
- single-command local gate (`bin/release-preflight`)
- version/tag parity guard (`bin/check-version-sync`)
- RubyGems CI credential preflight helper (`bin/verify-rubygems-api-key`)
- post-publish artifact verification helper (`bin/verify-release-publish`)
- deterministic release preparation helper (`bin/release-prepare`)
- release artifact builder with checksum output (`bin/release-artifacts`)
- precompiled artifact builder + runtime validator (`bin/release-precompiled-artifacts`)
- gemspec precompiled variant support (`LDA_RUBY_GEM_VARIANT=precompiled`)
- precompiled platform compatibility/publish policy (`docs/precompiled-platform-policy.md`)
- precompiled target expansion tracker (`docs/precompiled-target-evaluation.md`)
- macOS Rust build linker guardrail (`dynamic_lookup`) for precompiled packaging paths
- tag-driven release workflow (`.github/workflows/release.yml`)
- release failure alert workflow (`.github/workflows/release-failure-alert.yml`)
- maintainer release runbook (`docs/release-runbook.md`)
- CI jobs for packaged-gem fallback, rust-enabled checks, and manifest checks
- CI precompiled gem build guardrail job (`precompiled-gem-build`)
- release workflow matrix for precompiled gems:
  - `x86_64-linux`
  - `x86_64-darwin`
  - `arm64-darwin`

Open in Phase 5:

- optional expansion of precompiled targets (for example Windows and/or musl Linux)
- automated alerts/notifications for release artifact publish failures

## Validation Commands

Core:

- `./bin/docker-test`
- `./bin/docker-test-rust`

Packaging/release checks:

- `./bin/check-version-sync`
- `./bin/verify-rubygems-api-key`
- `./bin/verify-release-publish --tag v0.4.0`
- `./bin/test-packaged-gem-manifest`
- `./bin/test-packaged-gem-fallback`
- `./bin/test-packaged-gem-rust-enabled`
- `SKIP_DOCKER=1 ./bin/release-preflight`
- `./bin/release-artifacts --tag v0.4.0`
- `./bin/release-precompiled-artifacts --tag v0.4.0 --skip-preflight`

Optional full Docker matrix:

- `./bin/docker-test-install-policies`

Performance tracking:

- `./bin/benchmark-backends`
- `./bin/check-rust-benchmark`
- `docs/rust-orchestration-guardrails.md`
- CI currently enforces `BENCH_RUST_TO_PURE_MAX_RATIO=0.75` in `benchmark-guardrail`

## CI Jobs Expected

- native tests (`test-native`)
- pure backend tests (`test-pure`)
- rust runtime tests (`rust-runtime`)
- Docker install policy matrix (`install-policy-matrix`)
- packaged gem fallback checks (`packaged-gem-fallback`)
- packaged gem rust-enabled checks (`packaged-gem-rust-enabled`)
- packaged gem manifest checks (`packaged-gem-manifest`)
- precompiled gem build checks (`precompiled-gem-build`)
- rust scaffold check (`rust-scaffold`)
- benchmark guardrail check (`benchmark-guardrail`)
- release validation/build/publish pipeline on `v*` tags (`release.yml`)
- post-publish artifact verification (`verify_published_artifacts` in `release.yml`)
- release-failure issue alerting (`release-failure-alert`)

## Remaining Work Queue

Priority 1:

- continue periodic Rust-orchestration benchmark guardrail tightening (`docs/rust-orchestration-guardrails.md`) as performance data remains stable
- keep hybrid backend compatibility guarantees (Rust + native + pure fallback) while extending Rust orchestration only behind parity/guardrail checks

Priority 2:

- evaluate additional precompiled targets (Windows and/or musl Linux) using `docs/precompiled-target-evaluation.md`

Priority 3:

- monitor and tune release-failure issue alerting (`.github/workflows/release-failure-alert.yml`)

## Resume Instructions For A New Conversation

1. Check out `master`.
2. Open this file first: `docs/modernization-handoff.md`.
3. Run `SKIP_DOCKER=1 ./bin/release-preflight`.
4. Review `docs/release-runbook.md` for release flow/rollback details.
5. Validate precompiled packaging locally for your host:
   - `./bin/release-precompiled-artifacts --tag "$(./bin/check-version-sync --print-tag)" --skip-preflight`
6. Continue with remaining modernization queue (`Priority 2` then `Priority 3`).

If you want the next assistant to continue immediately, use:

"Open `docs/modernization-handoff.md`, validate with `SKIP_DOCKER=1 ./bin/release-preflight`, run `./bin/release-precompiled-artifacts --skip-preflight`, and continue the `Priority 2/3` modernization queue."
