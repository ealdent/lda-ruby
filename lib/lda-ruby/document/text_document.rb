module Lda
  class TextDocument < Document
    def initialize(corpus, text)
      super(corpus)
      tokenize(text)
      build_from_tokens
    end

    def has_text?
      true
    end

    def self.build_from_file(corpus, filename)
      text = File.open(filename, 'r') { |f| f.read }
      self.new(corpus, text)
    end

    protected

    def build_from_tokens
      vocab = Hash.new(0)
      @tokens.each { |t| vocab[t] = vocab[t] + 1 }

      vocab.each_pair do |word, count|
        @words << @corpus.vocabulary.check_word(word)
        @counts << count
      end

      recompute
    end
  end
end
