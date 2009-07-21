module Lda
  class TextDocument < Document
    attr_reader :tokens

    def initialize(tokens)
      @tokens = tokens
      super
    end

    class << self
      def build_from_file(filename)
        txt = File.open(filename, 'r') { |f| f.read }
        build_from_tokens(tokenize(txt))
      end

      def build(text)
        build_from_tokens(tokenize(text))
      end

      def build_from_tokens(tokens)
        vocab = Hash.new(0)
        tokens.each { |t| vocab[t] = vocab[t] + 1 }

        d = TextDocument.new(tokens)

        vocab.each_pair do |word, count|
          d.words << word
          d.counts << count
        end
        d.recompute

        d
      end

      def tokenize(txt)
        clean_text = txt.gsub(/[^A-Za-z'0-9\s]+/, ' ').gsub(/\s+/, ' ')        # remove everythign but letters, numbers, ' and leave only single spaces
        clean_text.split(' ')
      end
    end
  end
end
