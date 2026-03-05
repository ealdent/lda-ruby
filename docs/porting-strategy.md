# Ruby 3.2+/3.3+ Porting Strategy (Experimental)

## Recommendation

For this gem, the best long-term path is:

1. **Keep the public Ruby API.**
2. **Replace the handwritten C extension bindings with Rust + magnus** (Ruby native extension bindings for modern CRuby).
3. **Ship a pure-Ruby fallback backend** for portability and easier debugging.

This gives a practical balance between maintenance and speed:

- Pure Ruby only: easiest to maintain, but likely much slower for training.
- Modern C extension rewrite: fast, but still painful to maintain against Ruby internals.
- Rust extension: native speed with safer memory management and cleaner FFI layer.

## Why this path fits this project

- The current project already has a stable Ruby-facing object model (`Lda::Lda`, corpus/document classes).
- The expensive parts are numeric loops in inference/training, which benefit from native code.
- Ruby 3.2+ compatibility is much easier to preserve with a modern binding layer than with legacy C wrapper patterns.

## Proposed architecture

- `Lda::Backends::Rust` (preferred in `auto` mode when extension loads)
- `Lda::Backends::Native` (fallback in `auto` mode when Rust is unavailable)
- `Lda::Backends::PureRuby` (always available)
- `Lda::Lda` delegates heavy operations to the selected backend.

Suggested backend selection:

- `ENV['LDA_RUBY_BACKEND']=pure_ruby` → force Ruby backend.
- default (`auto`) → try Rust backend, then native backend, then pure Ruby.

## Migration plan

### Current status

Completed in `codex/experiment-ruby3-modernization`:

- Phase 1 baseline test capture expanded with backend compatibility fixtures.
- Phase 2 backend boundary extraction (`Lda::Lda` now delegates through backend adapters).
- Phase 3 pure Ruby backend implementation (available as `backend: :pure` or `LDA_RUBY_BACKEND=pure`).
- CI matrix added for Ruby 3.2/3.3 with native and pure backend jobs.
- Phase 4 started with Rust extension scaffolding (`ext/lda-ruby-rust`) and backend mode wiring (`backend: :rust` when extension is available).
- Rust kernels ported so far:
  - batched per-iteration corpus inference
  - batched per-document inference loop (EM inner updates)
  - per-word topic-weight computation
  - topic-term accumulation from per-document `phi`
  - topic-term normalization and log-beta finalization in EM
  - gamma convergence shift reduction between EM iterations
  - topic-document average log-probability computation
  - seeded topic-term initialization
- Rust runtime CI job added (compile + execute rust backend tests).
- Rust/Pure numeric parity fixtures added for deterministic seeded runs.
- `compile_rust` now stages a Ruby-loadable extension artifact to avoid `Init_` symbol mismatch from Cargo's `lib*` output naming.
- Rust-side EM orchestration path added (`Lda::RustBackend.run_em`) and retained as legacy compatibility fallback for precomputed beta-input execution.
- Rust-side deterministic-start orchestration path added (`Lda::RustBackend.run_em_with_start`) so `seeded`/`deterministic` startup can stay in Rust.
- Rust-side seed-controlled random-start orchestration path added (`Lda::RustBackend.run_em_with_start_seed` + `random_topic_term_probabilities`) so random initialization can stay in Rust while preserving deterministic replay from an explicit seed.
- Rust-side corpus session lifecycle added (`create_corpus_session`/`drop_corpus_session`) and `Lda::Backends::Rust` now prefers session-based EM orchestration (`run_em_on_session_with_start_seed`) before array-based fallback paths.
- Rust-side session settings lifecycle added (`configure_corpus_session`) and `Lda::Backends::Rust` now prefers settings-aware session orchestration (`run_em_on_session_start`) before parameter-heavy session and array-based fallbacks.
- Rust session orchestration now runs on shared Rust-side corpus session data via borrowed execution helpers, avoiding deep corpus array cloning on each session EM call.
- Unified Rust session API added (`run_em_on_session`) to apply settings and execute EM in one call; `Lda::Backends::Rust` now prefers this single-call session path before non-session fallbacks.
- `Lda::Backends::Rust` now prefers direct Rust non-session orchestration (`run_em_with_start_seed`) before legacy `run_em(initial_beta, ...)` compatibility fallback when a session path is unavailable.
- Rust managed-session orchestration API added (`run_em_on_session_with_corpus`) to recreate missing sessions and execute EM in one Rust call.
- `Lda::Backends::Rust` now retries missing-session runs through `run_em_on_session_with_corpus`, reducing fallback to non-session orchestration when sessions are externally dropped.
- Dockerized rust runtime workflow added for local parity with CI (`Dockerfile.rust`, `bin/docker-test-rust`).
- Gem packaging now excludes local Rust cargo build artifacts (`target/**`) for clean release builds.
- Backend benchmark driver added (`bin/benchmark-backends`) to track pure/native/rust runtime deltas.
- Rust orchestration guardrail policy documented (`docs/rust-orchestration-guardrails.md`) with benchmark threshold checker (`bin/check-rust-benchmark`).
- CI benchmark guardrail job added (`benchmark-guardrail`) to enforce Rust/pure runtime ratio on Ubuntu (currently `BENCH_RUST_TO_PURE_MAX_RATIO=0.05`).
- Source install path now has explicit Rust build policy via `LDA_RUBY_RUST_BUILD=auto|always|never`.
- Docker install-policy matrix script added (`bin/docker-test-install-policies`) to verify source install behavior across environments.
- CI now runs install-policy matrix checks on Ubuntu.
- Install-policy matrix now runs packaged-gem runtime smoke checks (auto/pure/native/rust mode selection + EM pipeline) to validate release-time fallback behavior.
- Cross-OS packaged-gem fallback CI job added (`bin/test-packaged-gem-fallback`) to validate auto/never/always install policy semantics without Cargo.
- Packaged-gem Rust-enabled CI job added (`bin/test-packaged-gem-rust-enabled`) to validate auto/never/always install policy semantics with Cargo available.
- Packaged-gem manifest CI job added (`bin/test-packaged-gem-manifest`) to enforce release artifact contents and metadata.
- Local release preflight command added (`bin/release-preflight`) to run unit + packaged-gem validation checks in one pass.
- Version/tag sync guard added (`bin/check-version-sync`) to enforce parity between `VERSION.yml`, `lib/lda-ruby/version.rb`, and release tags.
- Release preparation helper added (`bin/release-prepare`) for deterministic version/changelog updates.
- Release artifact helper added (`bin/release-artifacts`) to build source gem artifacts with SHA256 checksums.
- Precompiled platform artifact helper added (`bin/release-precompiled-artifacts`) to build + validate native gems.
- Tag-driven release workflow added (`.github/workflows/release.yml`) with dry-run support and environment-gated publish jobs.
- RubyGems credential preflight helper added (`bin/verify-rubygems-api-key`) for CI-safe publish key validation.
- Post-publish verification helper added (`bin/verify-release-publish`) to validate RubyGems + GitHub release artifacts by tag.
- CI precompiled guardrail job added (`precompiled-gem-build`) for full release-blocking platform packaging checks (Linux, Linux musl, macOS Intel, macOS Apple Silicon, Windows).
- macOS precompiled CI/release lanes now pin Homebrew `llvm@18` (with fallback to `llvm`) and export `LIBCLANG_PATH` from the selected prefix to avoid bindgen breakage from Homebrew LLVM drift.
- Release workflow post-publish verification job added (`verify_published_artifacts`).
- Release failure alert workflow added (`.github/workflows/release-failure-alert.yml`) to open issue alerts for failed tag-triggered `release.yml` runs and auto-close matching alerts when reruns succeed.
- Maintainer release runbook added (`docs/release-runbook.md`) with publish and rollback/yank procedures.
- Precompiled platform support policy added (`docs/precompiled-platform-policy.md`).

For an up-to-date resume snapshot (phase status + exact remaining queue), see `docs/modernization-handoff.md`.

### Phase 1: Stabilize API and tests

- Capture current behavior with golden tests around:
  - corpus loading
  - EM convergence hooks
  - topic-word output format
  - `top_words`, `top_word_indices`, and `phi` shape
- Add CI matrix for Ruby 3.2, 3.3, and latest.

### Phase 2: Extract backend boundary

- Introduce backend interface in Ruby.
- Keep all existing high-level classes and output methods.
- Route existing calls through one backend object.

### Phase 3: Add pure Ruby reference backend

- Implement a simple, correct (not necessarily fast) Gibbs or variational inference path.
- Use this backend in tests as the compatibility baseline.

### Phase 4: Add Rust native backend

- Implement performance-critical loops in Rust.
- Expose only minimal Ruby-facing methods.
- Verify parity against pure Ruby backend on deterministic fixtures.

### Phase 5: Packaging and release

- Phase 5A (source-gem release automation): complete.
- Keep source build path available.
- Phase 5B (precompiled/native gem publishing): complete for Linux/macOS/Windows/musl release matrix targets via `bin/release-precompiled-artifacts` and release workflow matrix builds.

## Tooling suggestions

- Ruby test framework: Minitest (already present).
- Native extension: `magnus` + `rb_sys`.
- Performance checks: benchmark script comparing legacy behavior vs pure Ruby vs Rust.
- CI: GitHub Actions with matrix (`ubuntu`, `macos`) and Ruby 3.2/3.3/latest.

## What not to do first

- Do not start by rewriting all algorithms at once.
- Do not couple file parsing and inference internals.
- Do not rely on old Ruby C API macros that changed across versions.

## Decision summary

If the goal is a future-proof gem with acceptable speed and much lower maintenance pain, **use a hybrid model (Rust native backend + pure Ruby fallback)** instead of a full pure-Ruby rewrite or another large handwritten C extension.
