require 'set'

module Lda
  class Corpus
    attr_reader :documents, :num_docs, :num_terms, :vocabulary

    def initialize
      @documents = Array.new
      @all_terms = Set.new
      @num_terms = @num_docs = 0
      @vocabulary = Vocabulary.new
    end

    def add_document(doc)
      raise 'Parameter +doc+ must be of type Document' unless doc.kind_of?(Document)

      @documents << doc

      @all_terms += doc.words
      @num_docs += 1
      @num_terms = @all_terms.size

      update_vocabulary(doc)
      nil
    end
	
	def remove_word(word)
		@vocabulary.words.delete word
	end
	
    protected

    def update_vocabulary(doc)
      doc.tokens.each { |w| @vocabulary.check_word(w) }
    end
  end
end
