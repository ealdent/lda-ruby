require_relative "test_helper"

class BackendCompatibilityTest < Test::Unit::TestCase
  FIXTURE_DOCUMENTS = [
    "apple banana apple banana fruit sweet fruit",
    "truck wheel truck road engine metal road",
    "ruby code gem ruby class module test",
    "banana fruit apple orchard fresh sweet",
    "engine road truck wheel fuel highway",
    "module ruby class object gem code"
  ].freeze

  def setup
    @corpus = Lda::TextCorpus.new(FIXTURE_DOCUMENTS)
  end

  def test_pure_backend_seeded_fixture
    lda = build_and_train(:pure)

    assert_equal "pure_ruby", lda.backend_name
    assert_backend_output_valid(lda)
  end

  def test_native_backend_seeded_fixture
    return unless Lda::NATIVE_EXTENSION_LOADED

    lda = build_and_train(:native)

    assert_equal "native", lda.backend_name
    assert_backend_output_valid(lda)
  end

  def test_native_and_pure_backend_agree_on_shapes
    return unless Lda::NATIVE_EXTENSION_LOADED

    native = build_and_train(:native)
    pure = build_and_train(:pure)

    assert_equal native.model[0], pure.model[0]
    assert_equal native.model[1], pure.model[1]
    assert_equal native.beta.size, pure.beta.size
    assert_equal native.gamma.size, pure.gamma.size
    assert_equal native.phi.size, pure.phi.size
  end

  private

  def build_and_train(backend)
    lda = Lda::Lda.new(@corpus, backend: backend, random_seed: 1234)
    lda.verbose = false
    lda.num_topics = 3
    lda.max_iter = 25
    lda.em_max_iter = 40
    lda.convergence = 1e-5
    lda.em_convergence = 1e-4
    lda.em("seeded")
    lda
  end

  def assert_backend_output_valid(lda)
    assert_equal 3, lda.model[0]
    assert lda.model[1] > 0

    assert_equal @corpus.num_docs, lda.gamma.size
    lda.gamma.each do |topic_weights|
      assert_equal 3, topic_weights.size
      topic_weights.each do |weight|
        assert weight.is_a?(Numeric)
        assert weight.finite?
        assert weight.positive?
      end
    end

    assert_equal 3, lda.beta.size
    lda.beta.each do |topic_log_probs|
      assert topic_log_probs.size > 0
      probabilities = topic_log_probs.map { |log_prob| Math.exp(log_prob) }
      assert_in_delta 1.0, probabilities.sum, 1e-3
    end

    phi = lda.phi
    assert_equal @corpus.num_docs, phi.size
    phi.each_with_index do |doc_phi, doc_index|
      assert_equal @corpus.documents[doc_index].length, doc_phi.size
      doc_phi.each do |word_topic_distribution|
        assert_equal 3, word_topic_distribution.size
        assert_in_delta 1.0, word_topic_distribution.sum, 1e-3
      end
    end

    probabilities = lda.compute_topic_document_probability
    assert_equal @corpus.num_docs, probabilities.size
    probabilities.each do |row|
      assert_equal 3, row.size
      row.each { |value| assert value.finite? }
    end

    top_words = lda.top_words(4)
    assert_equal 3, top_words.size
    top_words.each_value { |words| assert_equal 4, words.size }
  end
end
