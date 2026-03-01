# Precompiled Target Evaluation (Priority 2)

This document tracks current feasibility for expanding precompiled gem targets beyond the Phase 5B baseline.

Current release-blocking precompiled targets:

- `x86_64-linux`
- `x86_64-darwin`
- `arm64-darwin`

Reference implementation constraints:

- `bin/release-precompiled-artifacts` only supports host-matching platform builds (no cross-compilation).
- Release workflow currently uses matching host runners for each precompiled target.

## Candidate: Windows (`x64-mingw-ucrt`)

Status: not yet onboarded.

Feasibility notes:

- GitHub Actions provides Windows runners, so host-matching builds are possible in principle.
- Existing release tooling is bash-first and assumes POSIX shell ergonomics throughout.
- Runtime smoke and packaged-gem checks should be revalidated on RubyInstaller/Windows path and loader behavior.
- Candidate runs (2026-03-01):
  - [run 22555475302](https://github.com/ealdent/lda-ruby/actions/runs/22555475302): failed in native extension compile (`rake compile`) on Windows with `cokus.h` macro collision and `time_t` mismatch.
  - [run 22555550326](https://github.com/ealdent/lda-ruby/actions/runs/22555550326): after fixes, compile progressed but still fails on Windows at `utils.c` `mkdir(name, mode)` signature mismatch (needs Windows-safe `_mkdir` path handling).

Required validation to promote:

1. Run the manual candidate workflow `.github/workflows/precompiled-candidate-evaluation.yml` (windows job) and collect artifacts/logs.
2. Confirm produced gem platform identifier matches the intended Windows platform (`Gem::Platform.local` on runner).
3. Add Windows-specific packaged-gem runtime checks.
4. Run one release dry-run with the new matrix target before making it release-blocking.

## Candidate: musl Linux (`x86_64-linux-musl`)

Status: not yet onboarded.

Feasibility notes:

- Current workflow uses `ubuntu-latest` (glibc), not musl.
- Current artifact script rejects cross-platform builds, so a musl artifact requires either:
  - a musl-hosted builder, or
  - a dedicated musl-native build container/workflow path treated as host-equivalent for packaging.
- Local validation signal (2026-03-01): Alpine container dry-run succeeded for host-matching `aarch64-linux-musl` with:
  - `./bin/release-precompiled-artifacts --platform <detected-musl-platform> --skip-preflight --skip-runtime-checks`
- Candidate workflow runs (2026-03-01):
  - [run 22555475302](https://github.com/ealdent/lda-ruby/actions/runs/22555475302): built `x86_64-linux-musl` successfully but artifact upload path was misconfigured.
  - [run 22555550326](https://github.com/ealdent/lda-ruby/actions/runs/22555550326): musl candidate built and uploaded artifacts successfully with corrected glob path (`pkg/lda-ruby-*-linux-musl.gem*`).

Required validation to promote:

1. Run the manual candidate workflow `.github/workflows/precompiled-candidate-evaluation.yml` (musl job, auto-detected musl platform) and collect artifacts/logs.
2. Verify packaged gem metadata/platform and runtime smoke checks on musl.
3. Add the lane to release dry-run matrix before making musl release-blocking.

## Recommendation

Prioritize Windows evaluation first (lower infrastructure lift), then musl once a stable musl-native build lane exists.
