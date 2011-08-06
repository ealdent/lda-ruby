module Lda
  class TextDocument < Document
    attr_reader :filename

    def initialize(corpus, text)
      super(corpus)
      @filename = nil

      tokenize(text)
      @corpus.stopwords.each { |w| @tokens.delete(w) }
      build_from_tokens
    end

    def has_text?
      true
    end

    def self.build_from_file(corpus, filename)
      @filename = filename.dup.freeze
      text = File.open(@filename, 'r') { |f| f.read }
      self.new(corpus, text)
    end

    protected

    def build_from_tokens
      vocab = Hash.new(0)
      @tokens.each { |t| vocab[t] = vocab[t] + 1 }

      vocab.each_pair do |word, count|
        @words << @corpus.vocabulary.check_word(word) - 1
        @counts << count
      end

      recompute
    end
  end
end
