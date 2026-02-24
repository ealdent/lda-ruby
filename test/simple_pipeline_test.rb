require_relative "test_helper"

class SimplePipelineTest < Test::Unit::TestCase
  def test_end_to_end_pipeline_on_small_corpus
    corpus = Lda::Corpus.new
    document1 = Lda::TextDocument.new(corpus, "Dom Cobb is a skilled thief who steals secrets from dreams.")
    document2 = Lda::TextDocument.new(corpus, "Jake Sully joins the mission on Pandora and learns from the Na'vi.")

    corpus.add_document(document1)
    corpus.add_document(document2)
    corpus.remove_word("cobb")

    lda = Lda::Lda.new(corpus)
    lda.verbose = false
    lda.num_topics = 2
    lda.em("random")

    topics = lda.top_words(5)
    assert_equal 2, topics.size
    topics.each_value { |words| assert_equal 5, words.size }
  end
end
