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
      clean_text = text.gsub(/[^A-Za-z'\s]+/, ' ').gsub(/\s+/, ' ').downcase        # remove everything but letters and ' and leave only single spaces
      @tokens = handle(clean_text.split(' '))
	  @root ="#{File.expand_path('../..',__FILE__)}"
	  @filename = File.join(@root, "stopwords.txt")
	  file = File.new(@filename, "r")
	  stopwords = Array.new
	  
	  while (line = file.gets)
		stopwords.push line.strip
	  end
	  stopwords.each do |word|
		@tokens.delete word
	  end
    end
  end
end