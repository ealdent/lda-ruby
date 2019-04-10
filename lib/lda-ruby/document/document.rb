require 'yaml'

module Lda
  class Document
    attr_reader :corpus, :words, :counts, :length, :total, :tokens

    def initialize(corpus)
      @corpus = corpus

      @words  = []
      @counts = []
      @tokens = []
      @length = 0
      @total  = 0
    end

    #
    # Recompute the total and length values.
    #
    def recompute
      @total = @counts.inject(0) { |sum, i| sum + i }
      @length = @words.size
    end

    def text?
      false
    end

    def handle(tokens)
      tokens
    end

    def tokenize(text)
      # remove everything but letters and ' and leave only single spaces
      clean_text = text.gsub(/[^a-zäöüß'-]+/i, ' ').gsub(/\s+/, ' ').downcase
      @tokens = handle(clean_text.split(' '))
      nil
    end
  end
end
