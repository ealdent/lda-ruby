module Lda
  class TextDocument < Document
    attr_reader :tokens

    def initialize(tokens)
      @tokens = tokens
      super(nil)
    end

    class << self
      def build_from_file(corpus, filename)
        txt = File.open(filename, 'r') { |f| f.read }
        build_from_tokens(corpus, tokenize(txt))
      end

      def build(corpus, text)
        build_from_tokens(corpus, tokenize(text))
      end

      def build_from_tokens(corpus, tokens)
        vocab = Hash.new(0)
        tokens.each { |t| vocab[t] = vocab[t] + 1 }

        d = TextDocument.new(tokens)

        vocab.each_pair do |word, count|
          d.words << corpus.vocabulary.check_word(word)
          d.counts << count
        end
        d.recompute

        d
      end

      def tokenize(txt)
        clean_text = txt.gsub(/[^A-Za-z'0-9\s]+/, ' ').gsub(/\s+/, ' ')        # remove everythign but letters, numbers, ' and leave only single spaces
        handle(clean_text.split(' '))
      end

      # Override this method to add things like stemming, removal of stop words, etc
      def handle(tokens)
        tokens
      end
    end
  end
end
