module Lda
  class Vocabulary
    attr_reader :words

    def initialize(words = nil)
      @words = Hash.new do |hash, key|
        if hash.member?(:MAX_VALUE)
          hash[:MAX_VALUE] = hash[:MAX_VALUE] + 1
        else
          hash[:MAX_VALUE] = 1
        end
        hash[key] = hash[:MAX_VALUE]
      end

      words.each { |w| @words[w] } if words
    end

    def check_word(word)
      @words[word.dup]
    end

    def to_a
      @words.sort { |w1, w2| w1[1] <=> w2[1] }.map { |word, idx| word }.reject { |w| w == :MAX_VALUE }
    end
  end
end