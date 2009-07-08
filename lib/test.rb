require 'lda'
require 'test/unit'
require 'yaml'
$vocab_set = YAML.load_file('vocab_set.yml')
$vocab_vec = YAML.load_file('vocab_vec.yml')
$docs      = YAML.load_file('docs.yml')

class LdaTest < Test::Unit::TestCase
  def test_corpus
    corpus = Lda::Corpus.new
    $docs.each {|tf| corpus.add_document(tf) }
    assert_equal $docs.size, corpus.num_docs
    assert_equal $docs.size, corpus.documents.size
    assert_equal 1320, corpus.num_terms
  end

  def test_document
    d = Lda::Document.new("5 1:2 3:1 4:2 7:3 12:1")
    assert_equal 5, d.length
    assert_equal 9, d.total # total terms/words
    assert_equal [1, 3, 4, 7, 12], d.words
  end

  def test_lda_em_random
  end

  def test_lda_em_seed
  end

end
