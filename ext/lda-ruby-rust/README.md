# Experimental Rust Extension Scaffold

This directory contains an experimental Rust extension scaffold built with `magnus`.

Current scope:

- Defines `Lda::RustBackend` module in Ruby.
- Exposes capability hooks:
  - `Lda::RustBackend.available?`
  - `Lda::RustBackend.abi_version`
  - `Lda::RustBackend.corpus_session_count`
  - `Lda::RustBackend.corpus_session_exists(session_id)`
  - `Lda::RustBackend.before_em(start, num_docs, num_terms)`
  - `Lda::RustBackend.topic_weights_for_word(beta, gamma, word_index, min_probability)`
  - `Lda::RustBackend.accumulate_topic_term_counts(topic_term_counts, phi_d, words, counts)`
  - `Lda::RustBackend.infer_document(beta, gamma_initial, words, counts, max_iter, convergence, min_probability, init_alpha)`
  - `Lda::RustBackend.infer_corpus_iteration(beta, document_words, document_counts, max_iter, convergence, min_probability, init_alpha)`
  - `Lda::RustBackend.normalize_topic_term_counts(topic_term_counts, min_probability)`
  - `Lda::RustBackend.average_gamma_shift(previous_gamma, current_gamma)`
  - `Lda::RustBackend.topic_document_probability(phi_tensor, document_counts, num_topics, min_probability)`
  - `Lda::RustBackend.seeded_topic_term_probabilities(document_words, document_counts, topics, terms, min_probability)`
  - `Lda::RustBackend.random_topic_term_probabilities(topics, terms, min_probability, random_seed)`
  - `Lda::RustBackend.create_corpus_session(document_words, document_counts, terms)`
  - `Lda::RustBackend.drop_corpus_session(session_id)`
  - `Lda::RustBackend.configure_corpus_session(session_id, topics, max_iter, convergence, em_max_iter, em_convergence, init_alpha, min_probability)`
  - `Lda::RustBackend.run_em(initial_beta, document_words, document_counts, max_iter, convergence, em_max_iter, em_convergence, init_alpha, min_probability)`
  - `Lda::RustBackend.run_em_with_start(start, document_words, document_counts, topics, terms, max_iter, convergence, em_max_iter, em_convergence, init_alpha, min_probability)`
  - `Lda::RustBackend.run_em_with_start_seed(start, document_words, document_counts, topics, terms, max_iter, convergence, em_max_iter, em_convergence, init_alpha, min_probability, random_seed)`
  - `Lda::RustBackend.run_em_on_session(session_id, start, topics, max_iter, convergence, em_max_iter, em_convergence, init_alpha, min_probability, random_seed)`
  - `Lda::RustBackend.run_em_on_session_start(session_id, start, random_seed)`
  - `Lda::RustBackend.run_em_on_session_with_start_seed(session_id, start, topics, max_iter, convergence, em_max_iter, em_convergence, init_alpha, min_probability, random_seed)`

Hot-path kernels currently executed in Rust when `backend: :rust` is active:
- topic weights for a word across topics
- topic-term count accumulation from per-document `phi`
- full per-document inference loop (batched inner EM updates)
- full per-iteration corpus inference (batched document processing)
- topic-term normalization and log-probability finalization for EM beta updates
- gamma convergence shift reduction between EM iterations
- topic-document average log-probability computation
- seeded topic-term initialization
- random topic-term initialization with explicit seed control
- EM outer-loop orchestration with convergence checks (`run_em`)
- start-aware deterministic EM orchestration (`run_em_with_start` for `seeded`/`deterministic`)
- start-aware seeded and random EM orchestration with explicit seed control (`run_em_with_start_seed`)
- unified session-settings orchestration (`run_em_on_session`) that applies settings and executes EM in one call
- session-based EM orchestration against Rust-managed corpus lifecycle (`create_corpus_session` + `run_em_on_session_with_start_seed`)
- settings-aware session orchestration (`configure_corpus_session` + `run_em_on_session_start`)
- unknown EM start modes in seed-aware orchestration follow Ruby's non-seeded fallback behavior (seeded by explicit `random_seed`)

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
