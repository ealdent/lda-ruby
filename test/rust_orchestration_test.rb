# frozen_string_literal: true

require_relative "test_helper"

class RustOrchestrationTest < Test::Unit::TestCase
  FIXTURE_DOCUMENTS = [
    "ruby code gem ruby class module test",
    "rust backend speed ffi binding memory safety",
    "topic model inference corpus document probability",
    "module ruby class object gem code"
  ].freeze

  def setup
    omit("rust extension unavailable") unless Lda::RUST_EXTENSION_LOADED
    omit("run_em_with_start unavailable") unless defined?(Lda::RustBackend) && Lda::RustBackend.respond_to?(:run_em_with_start)

    @corpus = Lda::TextCorpus.new(FIXTURE_DOCUMENTS)
    @topics = 3
    @terms = @corpus.documents.flat_map(&:words).max + 1
    @document_words = @corpus.documents.map { |document| document.words.map(&:to_i) }
    @document_counts = @corpus.documents.map { |document| document.counts.map(&:to_f) }
    @max_iter = 25
    @convergence = 1e-5
    @em_max_iter = 40
    @em_convergence = 1e-4
    @init_alpha = 0.3
    @min_probability = 1e-12
  end

  def test_run_em_with_start_seeded_matches_explicit_seeded_initialization
    explicit_seed = Lda::RustBackend.seeded_topic_term_probabilities(
      @document_words,
      @document_counts,
      @topics,
      @terms,
      @min_probability
    )

    explicit = Lda::RustBackend.run_em(
      explicit_seed,
      @document_words,
      @document_counts,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability
    )

    with_start = Lda::RustBackend.run_em_with_start(
      "seeded",
      @document_words,
      @document_counts,
      @topics,
      @terms,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability
    )

    assert_nested_close(explicit, with_start, 1e-12)
  end

  def test_run_em_with_start_deterministic_alias_matches_seeded
    seeded = Lda::RustBackend.run_em_with_start(
      "seeded",
      @document_words,
      @document_counts,
      @topics,
      @terms,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability
    )

    deterministic = Lda::RustBackend.run_em_with_start(
      "deterministic",
      @document_words,
      @document_counts,
      @topics,
      @terms,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability
    )

    assert_nested_close(seeded, deterministic, 1e-12)
  end

  def test_run_em_with_start_seed_random_matches_explicit_random_initialization
    omit("run_em_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_with_start_seed)
    omit("random_topic_term_probabilities unavailable") unless Lda::RustBackend.respond_to?(:random_topic_term_probabilities)

    random_seed = 12_345
    explicit_seed = Lda::RustBackend.random_topic_term_probabilities(
      @topics,
      @terms,
      @min_probability,
      random_seed
    )

    explicit = Lda::RustBackend.run_em(
      explicit_seed,
      @document_words,
      @document_counts,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability
    )

    with_start = Lda::RustBackend.run_em_with_start_seed(
      "random",
      @document_words,
      @document_counts,
      @topics,
      @terms,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability,
      random_seed
    )

    assert_nested_close(explicit, with_start, 1e-12)
  end

  def test_run_em_with_start_seed_keeps_seeded_start_seed_independent
    omit("run_em_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_with_start_seed)

    left = Lda::RustBackend.run_em_with_start_seed(
      "seeded",
      @document_words,
      @document_counts,
      @topics,
      @terms,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability,
      101
    )

    right = Lda::RustBackend.run_em_with_start_seed(
      "seeded",
      @document_words,
      @document_counts,
      @topics,
      @terms,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability,
      202
    )

    assert_nested_close(left, right, 1e-12)
  end

  private

  def assert_nested_close(left, right, tolerance)
    if left.is_a?(Array)
      assert_equal left.size, right.size
      left.each_with_index do |left_item, index|
        assert_nested_close(left_item, right[index], tolerance)
      end
      return
    end

    assert_in_delta left.to_f, right.to_f, tolerance
  end
end
