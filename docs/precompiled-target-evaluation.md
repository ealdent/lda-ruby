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

Status: candidate workflow green (including runtime checks); not yet onboarded as release-blocking.

Feasibility notes:

- GitHub Actions provides Windows runners, so host-matching builds are possible in principle.
- Existing release tooling is bash-first and assumes POSIX shell ergonomics throughout.
- Runtime smoke and packaged-gem checks still need explicit Windows coverage before release-blocking promotion.
- Candidate runs:
  - [run 22555475302](https://github.com/ealdent/lda-ruby/actions/runs/22555475302): failed in native extension compile (`rake compile`) with `cokus.h` macro collision and `time_t` mismatch.
  - [run 22555550326](https://github.com/ealdent/lda-ruby/actions/runs/22555550326): progressed further, failed on `utils.c` `mkdir(name, mode)` mismatch (Windows `_mkdir` required).
  - [run 22556009214](https://github.com/ealdent/lda-ruby/actions/runs/22556009214): Rust bindgen/toolchain parsing fixed; build then failed on Windows DLL name staging expectation.
  - [run 22556129503](https://github.com/ealdent/lda-ruby/actions/runs/22556129503): Windows candidate build + artifact upload succeeded after GNU toolchain alignment, bindgen header/sysroot setup, and dual DLL name staging support.
  - [run 22556206925](https://github.com/ealdent/lda-ruby/actions/runs/22556206925): Windows candidate remained green with packaged-gem runtime smoke checks enabled.

Required validation to promote:

1. Run one release dry-run with a Windows target in the release matrix before making it release-blocking.

## Candidate: musl Linux (`x86_64-linux-musl`)

Status: candidate workflow green (including runtime checks); not yet onboarded as release-blocking.

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
  - [run 22556129503](https://github.com/ealdent/lda-ruby/actions/runs/22556129503): musl candidate build + artifact upload remained green alongside the fixed Windows lane.
  - [run 22556206925](https://github.com/ealdent/lda-ruby/actions/runs/22556206925): musl candidate remained green with packaged-gem runtime smoke checks enabled.

Required validation to promote:

1. Add the lane to release dry-run matrix before making musl release-blocking.

## Recommendation

Promote both candidates in staged order:
1. Run a release dry-run with both candidate targets included.
2. Make each target release-blocking only after dry-run stability is confirmed.
