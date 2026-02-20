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

- `Lda::Backend::Rust` (default when extension loads)
- `Lda::Backend::PureRuby` (always available)
- `Lda::Lda` delegates heavy operations to the selected backend.

Suggested backend selection:

- `ENV['LDA_RUBY_BACKEND']=pure_ruby` → force Ruby backend.
- default → try Rust backend, fallback to pure Ruby.

## Migration plan

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

- Build native gems where practical.
- Keep source build path available.
- Document fallback behavior clearly.

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
