#
# Create the Document using the svmlight-style text line:
#
#   num_words w1:freq1 w2:freq2 ... w_n:freq_n
#
# Ex.
#   5 1:2 3:1 4:2 7:3 12:1
#
# The value for the number of words should equal the number of pairs
# following it, though this isn't at all enforced.  Order of word-pair
# indices is not important.
#

module Lda
  class DataDocument < Document
    def initialize(corpus, data)
      super(corpus)

      items = data.split(/\s+/)
      pairs = items[1..items.size].map { |item| item.split(':') }

      pairs.each do |feature_identifier, feature_weight|
        @words << feature_identifier.to_i
        @counts << feature_weight.to_i
      end

      recompute
    end
  end
end
