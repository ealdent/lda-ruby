require 'test_helper'

class LdaRubyTest < Test::Unit::TestCase
  context "A Corpus instance" do
    context "A typical Lda::Corpus instance" do
      setup do
        @corpus = Lda::Corpus.new
        @document = Lda::TextDocument.new(@corpus, 'This is the document that never ends.  Oh wait yeah it does.')
      end

      should "be able to add new documents" do
        assert @corpus.respond_to?(:add_document)
        @corpus.add_document(@document)
        assert_equal @corpus.documents.size, 1
      end
    end

    context "An Lda::DataCorpus instance loaded from a file" do
      setup do
        @filename = 'data/docs.dat'
        @filetext = File.open(@filename, 'r') { |f| f.read }
        @corpus = Lda::DataCorpus.new(@filename)
      end

      should "contain the number of documents equivalent to the number of lines in the file" do
        assert_equal @corpus.num_docs, @filetext.split(/\n/).size
      end
    end

    context "An Lda::TextCorpus instance" do
      setup do
        @corpus = Lda::TextCorpus.new
      end
    end

    context "An Lda::TextCorpus instance loaded from a file" do
      setup do
        @corpus = Lda::TextCorpus.new
        @document = Lda::TextDocument.new(@corpus, 'This is the document that never ends.  Oh wait yeah it does.')
      end
    end
  end
end
