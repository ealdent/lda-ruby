# Experimental Rust Extension Scaffold

This directory contains an experimental Rust extension scaffold built with `magnus`.

Current scope:

- Defines `Lda::RustBackend` module in Ruby.
- Exposes capability hooks:
  - `Lda::RustBackend.available?`
  - `Lda::RustBackend.abi_version`
  - `Lda::RustBackend.before_em(start, num_docs, num_terms)`
  - `Lda::RustBackend.topic_weights_for_word(beta, gamma, word_index, min_probability)`
  - `Lda::RustBackend.accumulate_topic_term_counts(topic_term_counts, phi_d, words, counts)`
  - `Lda::RustBackend.infer_document(beta, gamma_initial, words, counts, max_iter, convergence, min_probability, init_alpha)`
  - `Lda::RustBackend.infer_corpus_iteration(beta, document_words, document_counts, max_iter, convergence, min_probability, init_alpha)`

Hot-path kernels currently executed in Rust when `backend: :rust` is active:
- topic weights for a word across topics
- topic-term count accumulation from per-document `phi`
- full per-document inference loop (batched inner EM updates)
- full per-iteration corpus inference (batched document processing)

Remaining numeric LDA kernels are still provided by the pure Ruby backend and will move incrementally.

## Local build (optional)

```bash
cd ext/lda-ruby-rust
cargo build --release
```

Then run Ruby with `require "lda_ruby_rust"` available on load path.

## Install-time policy

During source gem installs, `ext/lda-ruby-rust/extconf.rb` can optionally build this extension.

- `LDA_RUBY_RUST_BUILD=auto` (default): build when `cargo` is available.
- `LDA_RUBY_RUST_BUILD=always`: require a successful Rust build or fail installation.
- `LDA_RUBY_RUST_BUILD=never`: always skip Rust build.
