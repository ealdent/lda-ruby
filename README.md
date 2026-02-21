# Latent Dirichlet Allocation – Ruby Wrapper

## What is LDA-Ruby?

This wrapper is based on C-code by David M. Blei. In a nutshell, it can be used to automatically cluster documents into topics. The number of topics are chosen beforehand and the topics found are usually fairly intuitive. Details of the implementation can be found in the paper by Blei, Ng, and Jordan.

The original C code relied on files for the input and output. We felt it was necessary to depart from that model and use Ruby objects for these steps instead. The only file necessary will be the data file (in a format similar to that used by [SVMlight][svmlight]). Optionally you may need a vocabulary file to be able to extract the words belonging to topics.

### Example usage:

    require 'lda-ruby'
    corpus = Lda::DataCorpus.new("data/data_file.dat")
    lda = Lda::Lda.new(corpus)    # create an Lda object for training
    lda.em("random")              # run EM algorithm using random starting points
    lda.load_vocabulary("data/vocab.txt")
    lda.print_topics(20)          # print all topics with up to 20 words per topic

If you have general questions about Latent Dirichlet Allocation, I urge you to use the [topic models mailing list][topic-models], since the people who monitor that are very knowledgeable.  If you encounter bugs specific to lda-ruby, please post an issue on the Github project.

## Development

### Local (Ruby 3.2+)

```bash
bundle install
bundle exec rake test
```

### Docker (recommended for isolated setup)

```bash
./bin/docker-test
```

Rust backend runtime checks in Docker:

```bash
./bin/docker-test-rust
```

Install policy matrix checks in Docker:

```bash
./bin/docker-test-install-policies
```

For an interactive shell inside the dev container:

```bash
./bin/docker-shell
```

For an interactive shell with Rust toolchain + bindgen dependencies:

```bash
./bin/docker-shell-rust
```

### Build tasks

- `bundle exec rake compile` builds the native extension.
- `bundle exec rake compile_rust` builds the experimental Rust extension and stages a Ruby-loadable artifact (`lda_ruby_rust.<dlext>`).
- `bundle exec rake test` rebuilds the extension, then runs tests.
- `bundle exec rake build` builds the gem package.
- `bundle exec ruby -Ilib:test test/backend_compatibility_test.rb` runs backend compatibility fixtures.
- `LDA_RUBY_BACKEND=rust bundle exec ruby -Ilib:test test/backend_compatibility_test.rb` runs parity checks in rust mode.
- `./bin/benchmark-backends` benchmarks available backends (`pure`, `native`, `rust`) and prints JSON.
- `./bin/docker-test-install-policies` verifies source-install behavior for `LDA_RUBY_RUST_BUILD=auto|always|never`.

Benchmark environment variables:
- `BENCH_RUNS` (default: `3`)
- `BENCH_START` (default: `seeded`)
- `BENCH_TOPICS` (default: `8`)
- `BENCH_MAX_ITER` (default: `20`)
- `BENCH_EM_MAX_ITER` (default: `40`)

### Install-time Rust build policy

Source installs now run both extension setup scripts (`ext/lda-ruby/extconf.rb` and `ext/lda-ruby-rust/extconf.rb`).

Rust build policy is controlled by `LDA_RUBY_RUST_BUILD`:
- `auto` (default): build Rust extension if `cargo` is available, otherwise skip.
- `always`: require Rust extension build and fail install if unavailable.
- `never`: skip Rust extension build.

Examples:
- `LDA_RUBY_RUST_BUILD=always gem install lda-ruby`
- `LDA_RUBY_RUST_BUILD=never bundle exec rake compile`

### Backend selection

- Default mode is `auto`: native extension when available, otherwise pure Ruby.
- Force pure Ruby backend:
  - `Lda::Lda.new(corpus, backend: :pure)`
  - or `LDA_RUBY_BACKEND=pure`
- Force native backend:
  - `Lda::Lda.new(corpus, backend: :native)`
- Force Rust backend (when extension is available):
  - `Lda::Lda.new(corpus, backend: :rust)`
  - or `LDA_RUBY_BACKEND=rust`

`em("seeded")` is supported by both native and pure backends for deterministic fixture-oriented runs.

Rust status: the extension hook layer is scaffolded in `ext/lda-ruby-rust`. Current Rust kernels include batched per-iteration corpus inference, batched per-document inference, topic-weights-per-word, topic-term-count accumulation, topic-term normalization/log-beta finalization, and gamma-shift convergence reduction inside EM when `backend: :rust` is active; remaining model math still delegates to the pure Ruby backend. CI now runs dedicated rust-runtime checks and numeric parity fixtures against the pure backend.
`compile_rust` and `LDA_RUBY_RUST_BUILD=always` require a Rust toolchain plus Ruby development headers and `libclang`.
Gem packaging excludes local Rust build artifacts (`ext/lda-ruby-rust/target/**`) so local cargo outputs do not leak into published gems.

## Resources

+ [Blog post about LDA-Ruby][lda-ruby]
+ [David Blei's lda-c code][blei]
+ [Wikipedia article on LDA][wikipedia]
+ [Sample AP data][ap-data]

## References

Blei, David M., Ng, Andrew Y., and Jordan, Michael I. 2003. Latent dirichlet allocation. Journal of Machine Learning Research. 3 (Mar. 2003), 993-1022 [[pdf][pdf]].

[svmlight]: http://svmlight.joachims.org
[lda-ruby]: http://web.archive.org/web/20120616115448/http://mendicantbug.com/2008/11/17/lda-in-ruby/
[blei]: http://web.archive.org/web/20161126004857/http://www.cs.princeton.edu/~blei/lda-c/
[wikipedia]: http://en.wikipedia.org/wiki/Latent_Dirichlet_allocation
[ap-data]: http://web.archive.org/web/20160507090044/http://www.cs.princeton.edu/~blei/lda-c/ap.tgz
[pdf]: http://www.cs.princeton.edu/picasso/mats/BleiNgJordan2003_blei.pdf
[topic-models]: https://lists.cs.princeton.edu/mailman/listinfo/topic-models

## Modernization

For a Ruby 3.2+/3.3+ porting proposal, see `docs/porting-strategy.md`.
