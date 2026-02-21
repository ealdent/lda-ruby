# Experimental Rust Extension Scaffold

This directory contains an experimental Rust extension scaffold built with `magnus`.

Current scope:

- Defines `Lda::RustBackend` module in Ruby.
- Exposes capability hooks:
  - `Lda::RustBackend.available?`
  - `Lda::RustBackend.abi_version`
  - `Lda::RustBackend.before_em(start, num_docs, num_terms)`
  - `Lda::RustBackend.topic_weights_for_word(beta, gamma, word_index, min_probability)`

The first hot-path kernel (topic weights for a word across all topics) is now executed in Rust when the Rust backend is active. Remaining numeric LDA kernels are still provided by the pure Ruby backend and will move incrementally.

## Local build (optional)

```bash
cd ext/lda-ruby-rust
cargo build --release
```

Then run Ruby with `require "lda_ruby_rust"` available on load path.
