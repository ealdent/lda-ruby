module Lda
  class Document < BaseDocument
    attr_reader :words, :counts, :length, :total

    #
    # Create the Document using the svmlight-style text line:
    #
    #   num_words w1:freq1 w2:freq2 ... w_n:freq_n
    #
    # Ex.
    #   5 1:2 3:1 4:2 7:3 12:1
    #
    # The value for the number of words should equal the number of pairs
    # following it, though this isn't strictly enforced.  Order of word-pair
    # indices is not important.
    #
    def initialize(doc_line = nil)
      if doc_line.is_a?(String)
        tmp = doc_line.split
        @words = Array.new
        @counts = Array.new
        tmp[1..tmp.size].each do |pair|
          tmp2 = pair.split(':')
          @words << tmp2.first.to_i
          @counts << tmp2.last.to_i
        end
      else    # doc_line == nil
        @words = Array.new
        @counts = Array.new
      end

      recompute
    end

    #
    # Recompute the total and length values.
    #
    def recompute
      @total = @counts.inject(0) { |sum, i| sum + i }
      @length = @words.size
    end
  end
end