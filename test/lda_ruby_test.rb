require 'test_helper'

class LdaRubyTest < Test::Unit::TestCase
  context "A typical Lda::Corpus instance" do
    setup do
      @corpus = Lda::Corpus.new
      @document = Lda::TextDocument.build(@corpus, 'This is the document that never ends.  Oh wait yeah it does.')
    end

    should "be able to add new documents" do
      assert @corpus.respond_to?(:add_document)
      @corpus.add_document(@document)
      assert_equal @corpus.documents.size, 1
    end

  end
end
