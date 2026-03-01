# Precompiled Platform Gem Policy (Phase 5B)

This document defines the publish strategy and compatibility policy for `lda-ruby` precompiled gems.

## Artifact Strategy

Each release version publishes a split package set:

- Source gem: `lda-ruby-<version>.gem`
- Precompiled platform gems:
  - `lda-ruby-<version>-x86_64-linux.gem`
  - `lda-ruby-<version>-x86_64-darwin.gem`
  - `lda-ruby-<version>-arm64-darwin.gem`

The source gem remains the universal fallback. Platform gems are additive and are expected to install without local build tools.
Precompiled artifacts are built on matching host runners (no cross-compilation in current workflow).

## Compatibility Policy

- Supported Ruby versions: 3.2 and 3.3 (plus future versions validated by CI).
- Release-blocking precompiled targets:
  - Linux `x86_64-linux`
  - macOS Intel `x86_64-darwin`
  - macOS Apple Silicon `arm64-darwin`
- Other platforms:
  - Install from source gem.
  - Runtime remains supported through native/pure fallback paths.

Backend behavior expectations:

- Platform gem install:
  - `auto` backend resolves to `rust` by default.
  - `native` and `pure` overrides continue to work.
- Source gem install:
  - Rust build policy is controlled by `LDA_RUBY_RUST_BUILD=auto|always|never`.
  - If Rust build is skipped/unavailable, `auto` falls back to `native`, then `pure_ruby`.

## Guardrails

Validation must pass before publish:

- `./bin/release-preflight` (source-gem checks).
- `./bin/release-precompiled-artifacts --platform <target>` for each release-blocking platform.

Release automation requirements:

- `.github/workflows/release.yml` builds source + precompiled artifacts.
- Release workflow matrix must include all release-blocking precompiled targets.
- Publish jobs push all built gems and attach checksums to GitHub releases.
- Post-publish verification job must validate RubyGems entries and GitHub release assets for the tagged version.

Continuous integration guardrail:

- `.github/workflows/ci.yml` runs `release-precompiled-artifacts` for representative Linux/macOS targets on every branch/PR.

## Rollout / Expansion Rules

When adding a new precompiled platform:

1. Add target to release workflow matrix.
2. Add or update CI coverage for that platform family.
3. Update this policy and the release runbook support matrix.
4. Record feasibility evidence and rollout notes in `docs/precompiled-target-evaluation.md`.
5. Validate a dry-run release with `workflow_dispatch` before shipping.

When deprecating a precompiled platform:

1. Remove platform from release matrix.
2. Keep source-gem path available unless the overall platform support policy changes.
3. Document deprecation in `CHANGELOG.md` and release notes.
