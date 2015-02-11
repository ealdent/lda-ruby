# coding: utf-8
require 'yaml'

module Lda
  class Document
    attr_reader :corpus, :words, :counts, :length, :total, :tokens

    def initialize(corpus)
      @corpus = corpus

      @words  = Array.new
      @counts = Array.new
      @tokens = Array.new
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

    def has_text?
      false
    end

    def handle(tokens)
      tokens
    end

    def tokenize(text)
      clean_text = text.gsub(/[^a-zäöüß'-]+/i, ' ').gsub(/\s+/, ' ').downcase  # remove everything but letters and ' and leave only single spaces
      @tokens = handle(clean_text.split(' '))
      nil
    end
  end
end
