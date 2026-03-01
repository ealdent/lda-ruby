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

Required validation to promote:

1. Add a Windows precompiled build lane in CI (non-release) that runs:
   - `./bin/release-precompiled-artifacts --skip-preflight --skip-runtime-checks`
   - then Windows-specific packaged-gem runtime checks.
2. Confirm produced gem platform identifier matches the intended Windows platform (`Gem::Platform.local` on runner).
3. Run one release dry-run with the new matrix target before making it release-blocking.

## Candidate: musl Linux (`x86_64-linux-musl`)

Status: not yet onboarded.

Feasibility notes:

- Current workflow uses `ubuntu-latest` (glibc), not musl.
- Current artifact script rejects cross-platform builds, so a musl artifact requires either:
  - a musl-hosted builder, or
  - a dedicated musl-native build container/workflow path treated as host-equivalent for packaging.

Required validation to promote:

1. Introduce a musl-native build lane (for example Alpine-based builder workflow) that can build both native and Rust extensions.
2. Verify packaged gem metadata/platform and runtime smoke checks on musl.
3. Add the lane to release dry-run matrix before making musl release-blocking.

## Recommendation

Prioritize Windows evaluation first (lower infrastructure lift), then musl once a stable musl-native build lane exists.
