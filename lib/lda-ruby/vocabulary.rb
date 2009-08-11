module Lda
  class Vocabulary
    attr_reader :words, :indexes

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
      @indexes = Hash.new

      @words.each_pair do |w, i|
        @indexes[i] = w
      end
    end

    def check_word(word)
      w = @words[word.dup]
      @indexes[w] = word.dup
      w
    end

    def load_file(filename)
      txt = File.open(filename, 'r') { |f| f.read }
      txt.split(/[\n\r]+/).each { |word| check_word(word) }
    end

    def load_yaml(filename)
      YAML::load_file(filename).each { |word| check_word(word) }
    end

    def num_words
      ((@words.size > 0) ? @words.size - 1 : 0 )
    end

    def to_a
      @words.sort { |w1, w2| w1[1] <=> w2[1] }.map { |word, idx| word }.reject { |w| w == :MAX_VALUE }
    end
  end
end