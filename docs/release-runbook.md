# Release Runbook (Phase 5A + 5B)

This runbook defines the maintainer workflow for shipping `lda-ruby` source and precompiled platform gem releases.

Authoritative platform/support policy is maintained in `docs/precompiled-platform-policy.md`; expansion feasibility notes live in `docs/precompiled-target-evaluation.md`.

## Scope

- Release artifact types:
  - source gem: `pkg/lda-ruby-<version>.gem`
  - precompiled gems (current targets are defined in `docs/precompiled-platform-policy.md`)
- Release trigger: git tag (`vX.Y.Z`) with matching version files
- Publish targets:
  - RubyGems (`gem push`)
  - GitHub Releases (gem + checksum attachment)

## Prerequisites

1. Access:
   - push/tag rights on `master`
   - access to GitHub Actions environments for release approvals
   - RubyGems owner access for `lda-ruby`
2. Local tooling:
   - Ruby 3.2+ with Bundler
   - Rust toolchain (`cargo`) for local precompiled-gem build checks
   - `libclang` available to Rust bindgen
   - Docker (recommended for reproducible checks)
3. Repository state:
   - release commit merged to `master`
   - clean working tree
   - version files in sync

## Required Secrets and Environments

GitHub repository secret:

- `RUBYGEMS_API_KEY`: API key with push rights for `lda-ruby` and non-interactive publish support (no OTP prompt during `gem push`).

GitHub Actions environment:

- `release`: protect this environment with required reviewer approval.
- Both publish jobs in `.github/workflows/release.yml` are bound to `release`.

## Release Preparation

1. Prepare and update release files:

   ```bash
   ./bin/release-prepare 0.4.0
   ```

2. Review changes:
   - `VERSION.yml`
   - `lib/lda-ruby/version.rb`
   - `CHANGELOG.md`

3. Validate full release checks locally:

   ```bash
   SKIP_DOCKER=1 ./bin/release-preflight
   ./bin/test-packaged-gem-manifest
   ```

4. Validate local precompiled gem flow for your current host platform:

   ```bash
   ./bin/release-precompiled-artifacts --tag v0.4.0 --skip-preflight
   ```

   Note: `release-precompiled-artifacts` only supports building for the current host platform (no cross-compilation).

5. Verify RubyGems API key behavior before tagging:

   ```bash
   ./bin/verify-rubygems-api-key
   ```

   This check intentionally attempts a duplicate push of an existing gem version. A duplicate-rejected response is expected and confirms non-interactive auth works.

6. Commit and merge to `master`.

## Dry-Run Path (No Publish)

Use `workflow_dispatch` with `publish=false`.

Behavior:

- runs release validation and artifact build
- uploads source + precompiled `pkg/lda-ruby-*.gem` and checksum files as workflow artifacts
- does not push to RubyGems
- does not create a GitHub release

Latest verified dry-run reference:

- date: 2026-02-25
- workflow run: `https://github.com/ealdent/lda-ruby/actions/runs/22382692416`
- dispatch parameters: `release_tag=v0.4.0`, `publish=false`
- result: success across `validate`, `build_artifacts`, and full `build_precompiled_artifacts` matrix

Optional local dry-run equivalent:

```bash
./bin/release-artifacts --tag v0.4.0
./bin/release-precompiled-artifacts --tag v0.4.0 --skip-preflight
```

Candidate expansion workflow:

- For Priority 2 platform evaluation (for example Windows candidate artifacts), run `.github/workflows/precompiled-candidate-evaluation.yml` via `workflow_dispatch`.
- Record outcome artifacts/logs in `docs/precompiled-target-evaluation.md`.

## Known Publish Incident (`v0.4.0`)

- date: 2026-02-25
- release runs:
  - `https://github.com/ealdent/lda-ruby/actions/runs/22383716372`
  - `https://github.com/ealdent/lda-ruby/actions/runs/22383849236` (attempt 1 + rerun attempt 2 + rerun attempt 3)
- result: artifact build stages passed, `publish to RubyGems` failed with OTP-required auth (`You have enabled multifactor authentication but no OTP code provided.`)
- recovery action: rotated `release` environment secret `RUBYGEMS_API_KEY` to a CI-safe key and reran run `22383849236`.
- recovery result: rerun attempt 3 succeeded; RubyGems `0.4.0` and GitHub release `v0.4.0` published.

## Publish Path (Tag-Driven)

1. Ensure the release commit is on `master`.
2. Create and push the release tag:

   ```bash
   git checkout master
   git pull --ff-only
   git tag -a v0.4.0 -m "Release v0.4.0"
   git push origin v0.4.0
   ```

3. Monitor `.github/workflows/release.yml`:
   - `validate`
   - `build_artifacts`
   - `build_precompiled_artifacts` (linux + macOS matrix)
   - environment-gated `publish_rubygems`
   - environment-gated `publish_github_release`
   - `verify_published_artifacts`
4. Approve the protected `release` environment when prompted.
5. Confirm published outputs:
   - RubyGems shows `lda-ruby` `0.4.0` source gem and platform gems
   - GitHub release `v0.4.0` exists with all gem and `.sha256` attachments
   - workflow job `verify_published_artifacts` succeeds

## Rollback and Recovery

If publish fails before RubyGems push:

1. Fix issue on `master`.
2. Delete and recreate the tag only if the broken tag did not produce public artifacts:
   - `git tag -d vX.Y.Z`
   - `git push origin :refs/tags/vX.Y.Z`
3. Re-tag and re-run release.

If RubyGems push succeeds but GitHub release fails:

1. Re-run only the GitHub release path by re-running the workflow job after fix.
2. Do not re-push gem for the same version.

If an incorrect gem is published:

1. Yank from RubyGems:

   ```bash
   gem yank lda-ruby -v X.Y.Z
   ```

2. Publish a corrective version (for example `X.Y.(Z+1)`), do not re-use yanked version numbers.
3. Update `CHANGELOG.md` and release notes to document the correction.

## Troubleshooting

- `Could not find 'bundler'`: install the Bundler version pinned in `Gemfile.lock`.
- `cargo not found` in rust-enabled checks: ensure Rust toolchain is installed or run in Docker.
- `libclang` not found while building precompiled gems: install LLVM/libclang and set `LIBCLANG_PATH` if needed.
- Linux `Install Rust bindgen dependencies` can take several minutes on fresh runners due apt package index and package installs.
- RubyGems publish asks for OTP (`You have enabled multi-factor authentication but no OTP code provided`): run `./bin/verify-rubygems-api-key`, then rotate `RUBYGEMS_API_KEY` to a CI-safe key if OTP is requested.
- Post-publish verification fails: run `./bin/verify-release-publish --tag vX.Y.Z` and fix missing RubyGems entries or GitHub release assets before considering the release complete.
- macOS Rust link errors (`symbol(s) not found` for Ruby APIs): ensure build path preserves `-C link-arg=-Wl,-undefined,dynamic_lookup` in `RUSTFLAGS`.
- Tag/version mismatch: run `./bin/check-version-sync --tag vX.Y.Z`.
- Artifact mismatch during release: rebuild with `./bin/release-artifacts --tag vX.Y.Z`.
- Precompiled artifact mismatch: rebuild with `./bin/release-precompiled-artifacts --tag vX.Y.Z --skip-preflight`.
