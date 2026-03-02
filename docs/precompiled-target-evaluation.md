# Precompiled Target Evaluation (Priority 2)

This document tracks current feasibility for expanding precompiled gem targets beyond the Phase 5B baseline.

Current release-blocking precompiled targets:

- `x86_64-linux`
- `x86_64-darwin`
- `arm64-darwin`
- `x64-mingw-ucrt`
- `x86_64-linux-musl`

Reference implementation constraints:

- `bin/release-precompiled-artifacts` only supports host-matching platform builds (no cross-compilation).
- Release workflow currently uses matching host runners for each precompiled target.

## Candidate: Windows (`x64-mingw-ucrt`)

Status: promoted to release-blocking after release dry-run matrix success.

Feasibility notes:

- GitHub Actions provides Windows runners, so host-matching builds are possible in principle.
- Existing release tooling is bash-first and assumes POSIX shell ergonomics throughout.
- Runtime smoke and packaged-gem checks were validated in candidate runs before promotion.
- Candidate runs:
  - [run 22555475302](https://github.com/ealdent/lda-ruby/actions/runs/22555475302): failed in native extension compile (`rake compile`) with `cokus.h` macro collision and `time_t` mismatch.
  - [run 22555550326](https://github.com/ealdent/lda-ruby/actions/runs/22555550326): progressed further, failed on `utils.c` `mkdir(name, mode)` mismatch (Windows `_mkdir` required).
  - [run 22556009214](https://github.com/ealdent/lda-ruby/actions/runs/22556009214): Rust bindgen/toolchain parsing fixed; build then failed on Windows DLL name staging expectation.
  - [run 22556129503](https://github.com/ealdent/lda-ruby/actions/runs/22556129503): Windows candidate build + artifact upload succeeded after GNU toolchain alignment, bindgen header/sysroot setup, and dual DLL name staging support.
  - [run 22556206925](https://github.com/ealdent/lda-ruby/actions/runs/22556206925): Windows candidate remained green with packaged-gem runtime smoke checks enabled.
  - [run 22556487788](https://github.com/ealdent/lda-ruby/actions/runs/22556487788): release workflow dry-run succeeded with `windows-x64-mingw-ucrt` included in release matrix.

Required validation to promote:

1. Completed: release dry-run matrix validation passed.

## Candidate: musl Linux (`x86_64-linux-musl`)

Status: promoted to release-blocking after release dry-run matrix success.

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
  - [run 22556487788](https://github.com/ealdent/lda-ruby/actions/runs/22556487788): release workflow dry-run succeeded with `linux-musl-x86_64` included in release matrix.

Required validation to promote:

1. Completed: release dry-run matrix validation passed.

## Recommendation

Current expansion step is complete for Windows and musl. Any additional target should follow the same sequence:
1. Add candidate workflow coverage.
2. Verify candidate runtime checks.
3. Validate one release dry-run with the new matrix lane before promotion.
