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

  def test_run_em_on_session_seeded_matches_direct_seeded_start
    omit("create_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:create_corpus_session)
    omit("drop_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:drop_corpus_session)
    omit("run_em_on_session_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_on_session_with_start_seed)
    omit("run_em_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_with_start_seed)

    session_id = Lda::RustBackend.create_corpus_session(@document_words, @document_counts, @terms)
    assert_operator session_id, :>, 0

    direct = Lda::RustBackend.run_em_with_start_seed(
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
      777
    )

    via_session = Lda::RustBackend.run_em_on_session_with_start_seed(
      session_id,
      "seeded",
      @topics,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability,
      777
    )

    assert_nested_close(direct, via_session, 1e-12)
    assert_equal true, Lda::RustBackend.drop_corpus_session(session_id)
    assert_equal false, Lda::RustBackend.drop_corpus_session(session_id)
  end

  def test_run_em_on_session_random_matches_direct_random_start
    omit("create_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:create_corpus_session)
    omit("drop_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:drop_corpus_session)
    omit("run_em_on_session_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_on_session_with_start_seed)
    omit("run_em_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_with_start_seed)

    session_id = Lda::RustBackend.create_corpus_session(@document_words, @document_counts, @terms)
    assert_operator session_id, :>, 0

    direct = Lda::RustBackend.run_em_with_start_seed(
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
      55_555
    )

    via_session = Lda::RustBackend.run_em_on_session_with_start_seed(
      session_id,
      "random",
      @topics,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability,
      55_555
    )

    assert_nested_close(direct, via_session, 1e-12)
    assert_equal true, Lda::RustBackend.drop_corpus_session(session_id)
  end

  def test_run_em_on_session_unknown_start_matches_random_start
    omit("create_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:create_corpus_session)
    omit("drop_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:drop_corpus_session)
    omit("run_em_on_session unavailable") unless Lda::RustBackend.respond_to?(:run_em_on_session)
    omit("run_em_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_with_start_seed)

    session_id = Lda::RustBackend.create_corpus_session(@document_words, @document_counts, @terms)
    assert_operator session_id, :>, 0

    random_seed = 4545
    direct = Lda::RustBackend.run_em_with_start_seed(
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

    via_session = Lda::RustBackend.run_em_on_session(
      session_id,
      "unknown_mode",
      @topics,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability,
      random_seed
    )

    assert_nested_close(direct, via_session, 1e-12)
    assert_equal true, Lda::RustBackend.drop_corpus_session(session_id)
  end

  def test_run_em_on_session_start_uses_configured_settings
    omit("create_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:create_corpus_session)
    omit("drop_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:drop_corpus_session)
    omit("configure_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:configure_corpus_session)
    omit("run_em_on_session_start unavailable") unless Lda::RustBackend.respond_to?(:run_em_on_session_start)
    omit("run_em_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_with_start_seed)

    session_id = Lda::RustBackend.create_corpus_session(@document_words, @document_counts, @terms)
    assert_operator session_id, :>, 0
    assert_equal true, Lda::RustBackend.configure_corpus_session(
      session_id,
      @topics,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability
    )

    direct = Lda::RustBackend.run_em_with_start_seed(
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
      9090
    )

    via_session = Lda::RustBackend.run_em_on_session_start(
      session_id,
      "seeded",
      9090
    )

    assert_nested_close(direct, via_session, 1e-12)
    assert_equal true, Lda::RustBackend.drop_corpus_session(session_id)
  end

  def test_run_em_on_session_start_requires_configuration
    omit("create_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:create_corpus_session)
    omit("drop_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:drop_corpus_session)
    omit("configure_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:configure_corpus_session)
    omit("run_em_on_session_start unavailable") unless Lda::RustBackend.respond_to?(:run_em_on_session_start)

    session_id = Lda::RustBackend.create_corpus_session(@document_words, @document_counts, @terms)
    assert_operator session_id, :>, 0

    unconfigured = Lda::RustBackend.run_em_on_session_start(session_id, "seeded", 1)
    assert_equal [[], [], [], []], unconfigured

    assert_equal true, Lda::RustBackend.configure_corpus_session(
      session_id,
      @topics,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability
    )

    configured = Lda::RustBackend.run_em_on_session_start(session_id, "seeded", 1)
    assert_equal @topics, configured[0].size
    assert_equal @document_words.size, configured[2].size
    assert_equal true, Lda::RustBackend.drop_corpus_session(session_id)
  end

  def test_run_em_on_session_applies_settings_and_matches_direct_seeded_start
    omit("create_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:create_corpus_session)
    omit("drop_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:drop_corpus_session)
    omit("run_em_on_session unavailable") unless Lda::RustBackend.respond_to?(:run_em_on_session)
    omit("run_em_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_with_start_seed)

    session_id = Lda::RustBackend.create_corpus_session(@document_words, @document_counts, @terms)
    assert_operator session_id, :>, 0

    direct = Lda::RustBackend.run_em_with_start_seed(
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
      8181
    )

    via_session = Lda::RustBackend.run_em_on_session(
      session_id,
      "seeded",
      @topics,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability,
      8181
    )

    assert_nested_close(direct, via_session, 1e-12)
    assert_equal true, Lda::RustBackend.drop_corpus_session(session_id)
  end

  def test_run_em_on_session_reconfigures_topic_count
    omit("create_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:create_corpus_session)
    omit("drop_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:drop_corpus_session)
    omit("run_em_on_session unavailable") unless Lda::RustBackend.respond_to?(:run_em_on_session)

    session_id = Lda::RustBackend.create_corpus_session(@document_words, @document_counts, @terms)
    assert_operator session_id, :>, 0

    two_topics = Lda::RustBackend.run_em_on_session(
      session_id,
      "seeded",
      2,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability,
      5151
    )
    assert_equal 2, two_topics[0].size

    four_topics = Lda::RustBackend.run_em_on_session(
      session_id,
      "seeded",
      4,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability,
      5151
    )
    assert_equal 4, four_topics[0].size

    assert_equal true, Lda::RustBackend.drop_corpus_session(session_id)
  end

  def test_run_em_on_session_with_corpus_recreates_missing_session
    omit("create_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:create_corpus_session)
    omit("drop_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:drop_corpus_session)
    omit("run_em_on_session_with_corpus unavailable") unless Lda::RustBackend.respond_to?(:run_em_on_session_with_corpus)
    omit("run_em_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_with_start_seed)

    recreated_session_id = nil
    session_id = Lda::RustBackend.create_corpus_session(@document_words, @document_counts, @terms)
    assert_operator session_id, :>, 0
    assert_equal true, Lda::RustBackend.drop_corpus_session(session_id)

    managed = Lda::RustBackend.run_em_on_session_with_corpus(
      session_id,
      @document_words,
      @document_counts,
      @terms,
      "seeded",
      @topics,
      @max_iter,
      @convergence,
      @em_max_iter,
      @em_convergence,
      @init_alpha,
      @min_probability,
      6161
    )

    assert_equal 5, managed.size
    recreated_session_id = managed[0]
    assert_operator recreated_session_id, :>, 0
    assert_not_equal session_id, recreated_session_id

    direct = Lda::RustBackend.run_em_with_start_seed(
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
      6161
    )

    assert_nested_close(direct, managed[1..], 1e-12)
  ensure
    if recreated_session_id && recreated_session_id.positive?
      Lda::RustBackend.drop_corpus_session(recreated_session_id)
    end
  end

  def test_rust_backend_corpus_session_lifecycle_no_leak
    omit("corpus_session_count unavailable") unless Lda::RustBackend.respond_to?(:corpus_session_count)

    starting_count = Lda::RustBackend.corpus_session_count
    backend = Lda::Backends::Rust.new(random_seed: 1234)

    backend.corpus = Lda::TextCorpus.new(FIXTURE_DOCUMENTS)
    assert_equal starting_count + 1, Lda::RustBackend.corpus_session_count

    backend.corpus = Lda::TextCorpus.new(FIXTURE_DOCUMENTS.reverse)
    assert_equal starting_count + 1, Lda::RustBackend.corpus_session_count

    backend.corpus = nil
    assert_equal starting_count, Lda::RustBackend.corpus_session_count
  ensure
    backend&.corpus = nil
  end

  def test_rust_backend_recreates_missing_session_before_em
    omit("corpus_session_count unavailable") unless Lda::RustBackend.respond_to?(:corpus_session_count)
    omit("drop_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:drop_corpus_session)

    backend = Lda::Backends::Rust.new(random_seed: 1234)
    backend.corpus = Lda::TextCorpus.new(FIXTURE_DOCUMENTS)
    backend.num_topics = @topics

    session_id = backend.instance_variable_get(:@rust_corpus_session_id)
    assert_operator session_id, :>, 0
    assert_equal true, Lda::RustBackend.drop_corpus_session(session_id)

    backend.em("seeded")
    assert_equal @topics, backend.gamma.first.size

    recreated_session_id = backend.instance_variable_get(:@rust_corpus_session_id)
    assert_operator recreated_session_id, :>, 0
    assert_not_equal session_id, recreated_session_id
  ensure
    backend&.corpus = nil
  end

  def test_rust_backend_non_session_fallback_prefers_run_em_with_start_seed
    backend = nil
    rust_singleton = nil
    run_em_alias = :__test_original_run_em_for_non_session_fallback__
    run_em_with_start_seed_alias = :__test_original_run_em_with_start_seed_for_non_session_fallback__

    omit("run_em unavailable") unless Lda::RustBackend.respond_to?(:run_em)
    omit("run_em_with_start_seed unavailable") unless Lda::RustBackend.respond_to?(:run_em_with_start_seed)

    backend = Lda::Backends::Rust.new(random_seed: 1234)
    backend.corpus = Lda::TextCorpus.new(FIXTURE_DOCUMENTS)
    backend.verbose = false
    backend.num_topics = @topics
    backend.max_iter = @max_iter
    backend.convergence = @convergence
    backend.em_max_iter = @em_max_iter
    backend.em_convergence = @em_convergence
    backend.init_alpha = @init_alpha

    # Force the direct non-session orchestration path.
    backend.define_singleton_method(:ensure_rust_corpus_session) { false }

    rust_singleton = Lda::RustBackend.singleton_class
    run_em_calls = 0
    run_em_with_start_seed_calls = 0

    silence_redefinition_warnings do
      rust_singleton.send(:alias_method, run_em_alias, :run_em)
      rust_singleton.send(:alias_method, run_em_with_start_seed_alias, :run_em_with_start_seed)

      rust_singleton.send(:define_method, :run_em) do |*args|
        run_em_calls += 1
        public_send(run_em_alias, *args)
      end

      rust_singleton.send(:define_method, :run_em_with_start_seed) do |*args|
        run_em_with_start_seed_calls += 1
        public_send(run_em_with_start_seed_alias, *args)
      end
    end

    backend.em("random")
    assert_equal 0, run_em_calls
    assert_equal 1, run_em_with_start_seed_calls
    assert_equal @topics, backend.gamma.first.size
  ensure
    silence_redefinition_warnings do
      if defined?(rust_singleton) && rust_singleton.method_defined?(run_em_with_start_seed_alias)
        rust_singleton.send(:remove_method, :run_em_with_start_seed)
        rust_singleton.send(:alias_method, :run_em_with_start_seed, run_em_with_start_seed_alias)
        rust_singleton.send(:remove_method, run_em_with_start_seed_alias)
      end

      if defined?(rust_singleton) && rust_singleton.method_defined?(run_em_alias)
        rust_singleton.send(:remove_method, :run_em)
        rust_singleton.send(:alias_method, :run_em, run_em_alias)
        rust_singleton.send(:remove_method, run_em_alias)
      end
    end

    backend&.corpus = nil
  end

  def test_configure_corpus_session_reconfigures_topic_count
    omit("create_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:create_corpus_session)
    omit("drop_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:drop_corpus_session)
    omit("configure_corpus_session unavailable") unless Lda::RustBackend.respond_to?(:configure_corpus_session)
    omit("run_em_on_session_start unavailable") unless Lda::RustBackend.respond_to?(:run_em_on_session_start)

    session_id = Lda::RustBackend.create_corpus_session(@document_words, @document_counts, @terms)
    assert_operator session_id, :>, 0

    assert_equal true, Lda::RustBackend.configure_corpus_session(
      session_id, 2, @max_iter, @convergence, @em_max_iter, @em_convergence, @init_alpha, @min_probability
    )
    two_topics = Lda::RustBackend.run_em_on_session_start(session_id, "seeded", 303)
    assert_equal 2, two_topics[0].size

    assert_equal true, Lda::RustBackend.configure_corpus_session(
      session_id, 4, @max_iter, @convergence, @em_max_iter, @em_convergence, @init_alpha, @min_probability
    )
    four_topics = Lda::RustBackend.run_em_on_session_start(session_id, "seeded", 303)
    assert_equal 4, four_topics[0].size

    assert_equal true, Lda::RustBackend.drop_corpus_session(session_id)
  end

  def test_rust_backend_session_config_tracks_setting_changes
    backend = Lda::Backends::Rust.new(random_seed: 1234)
    backend.corpus = Lda::TextCorpus.new(FIXTURE_DOCUMENTS)
    backend.verbose = false
    backend.max_iter = 12
    backend.em_max_iter = 18
    backend.convergence = 1e-5
    backend.em_convergence = 1e-4

    backend.num_topics = 2
    backend.em("seeded")
    assert_equal 2, backend.gamma.first.size

    backend.num_topics = 4
    backend.em("seeded")
    assert_equal 4, backend.gamma.first.size
  ensure
    backend&.corpus = nil
  end

  private

  def silence_redefinition_warnings
    previous_verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = previous_verbose
  end

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
