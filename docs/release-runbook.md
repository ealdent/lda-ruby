# Release Runbook (Phase 5A + 5B)

This runbook defines the maintainer workflow for shipping `lda-ruby` source and precompiled platform gem releases.

Authoritative platform/support policy is maintained in `docs/precompiled-platform-policy.md`.

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

- `RUBYGEMS_API_KEY`: API key with push rights for `lda-ruby`.

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

5. Commit and merge to `master`.

## Dry-Run Path (No Publish)

Use `workflow_dispatch` with `publish=false`.

Behavior:

- runs release validation and artifact build
- uploads source + precompiled `pkg/lda-ruby-*.gem` and checksum files as workflow artifacts
- does not push to RubyGems
- does not create a GitHub release

Optional local dry-run equivalent:

```bash
./bin/release-artifacts --tag v0.4.0
./bin/release-precompiled-artifacts --tag v0.4.0 --skip-preflight
```

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
4. Approve the protected `release` environment when prompted.
5. Confirm published outputs:
   - RubyGems shows `lda-ruby` `0.4.0` source gem and platform gems
   - GitHub release `v0.4.0` exists with all gem and `.sha256` attachments

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
- Tag/version mismatch: run `./bin/check-version-sync --tag vX.Y.Z`.
- Artifact mismatch during release: rebuild with `./bin/release-artifacts --tag vX.Y.Z`.
- Precompiled artifact mismatch: rebuild with `./bin/release-precompiled-artifacts --tag vX.Y.Z --skip-preflight`.
