require_relative "test_helper"

class PureRubyOrchestrationTest < Test::Unit::TestCase
  FIXTURE_DOCUMENTS = [
    "apple banana apple banana fruit sweet fruit",
    "truck wheel truck road engine metal road",
    "ruby code gem ruby class module test",
    "banana fruit apple orchard fresh sweet",
    "engine road truck wheel fuel highway",
    "module ruby class object gem code"
  ].freeze

  def test_rust_em_input_includes_expected_fields
    backend = build_backend

    em_input = backend.rust_em_input("seeded")

    assert_equal 3, em_input[:topics]
    assert_equal em_input[:document_words].size, em_input[:document_counts].size
    assert_equal em_input[:document_words].map(&:length), em_input[:document_lengths]
    assert_equal em_input[:document_counts].map { |counts| counts.sum.to_f }, em_input[:document_totals]
    assert_equal 3, em_input[:initial_beta_probabilities].size
    assert em_input[:terms] > 0
  end

  def test_em_from_input_matches_seeded_em_output
    direct = build_backend
    from_input = build_backend

    direct.em("seeded")
    em_input = from_input.rust_em_input("seeded")
    from_input.em_from_input(em_input)

    assert_nested_close(direct.gamma, from_input.gamma, 1e-9)
    assert_nested_close(direct.beta, from_input.beta, 1e-9)
    assert_nested_close(direct.compute_phi, from_input.compute_phi, 1e-9)
  end

  def test_rust_initial_beta_probabilities_matches_rust_em_input_for_random_start
    from_helper = build_backend
    from_input = build_backend

    document_words = from_helper.corpus.documents.map { |document| document.words.map(&:to_i) }
    document_counts = from_helper.corpus.documents.map { |document| document.counts.map(&:to_f) }
    terms = from_helper.corpus.documents.flat_map(&:words).max + 1

    helper_beta = from_helper.rust_initial_beta_probabilities(
      "random",
      document_words,
      document_counts,
      from_helper.num_topics,
      terms
    )
    em_input = from_input.rust_em_input("random")

    assert_nested_close(helper_beta, em_input[:initial_beta_probabilities], 1e-12)
  end

  def test_apply_em_state_sets_outputs
    backend = build_backend

    docs = backend.corpus.documents
    topics = 3
    terms = 5

    beta_probabilities = Array.new(topics) { Array.new(terms, 1.0 / terms) }
    beta_log = beta_probabilities.map { |row| row.map { |probability| Math.log(probability) } }
    gamma = Array.new(docs.size) { Array.new(topics, 1.0) }
    phi = docs.map { |document| Array.new(document.length) { Array.new(topics, 1.0 / topics) } }

    backend.apply_em_state(
      beta_probabilities: beta_probabilities,
      beta_log: beta_log,
      gamma: gamma,
      phi: phi
    )

    assert_equal beta_log, backend.beta
    assert_equal gamma, backend.gamma
    assert_equal phi, backend.compute_phi
  end

  private

  def build_backend
    backend = Lda::Backends::PureRuby.new(random_seed: 1234)
    backend.corpus = Lda::TextCorpus.new(FIXTURE_DOCUMENTS)
    backend.verbose = false
    backend.num_topics = 3
    backend.max_iter = 25
    backend.em_max_iter = 40
    backend.convergence = 1e-5
    backend.em_convergence = 1e-4
    backend
  end

  def assert_nested_close(left, right, tolerance)
    assert_equal left.class, right.class

    if left.is_a?(Array)
      assert_equal left.size, right.size
      left.each_with_index do |left_item, index|
        assert_nested_close(left_item, right[index], tolerance)
      end
    else
      assert_in_delta left.to_f, right.to_f, tolerance
    end
  end
end
