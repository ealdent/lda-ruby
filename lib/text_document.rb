require 'set'
require 'stemmer'

module Lda
  
  class TextDocument < Lda::BaseDocument
    attr_accessor :words, :counts
    attr_reader :length, :total

    #
    # Create a document from a text file or string.
    # 
    def initialize(document, use_stemming=false)
      if File.exists?(document)
        txt = File.open(document, 'r') { |f| f.read.strip }
      else
        txt = document.to_s   # clone it
      end
      @counts = Array.new
      @words = Array.new
      @length = @total = 0
      process_text(txt, use_stemming)
    end
    

    def process_text(txt, use_stemming=false)
      @vocab = Hash.new(0)
      words = txt.downcase.gsub(/[^A-Za-z'0-9\s]/i, ' ').gsub(/\s+/, ' ').split(" ")
      words.map! { |word| word.stem } if use_stemming
      words.each do |word|
        @vocab[word] = @vocab[word] + 1
      end
      
      nil
    end
    
    
    #
    # Recompute the total and length values if the document has been
    # altered externally.  This probably won't happen, but might be useful
    # if you want to subclass +Document+.
    #
    def recompute
      @total = @counts.inject(0) {|sum, i| sum + i}
      @length = @words.size
    end
  end
  
  
  class TextCorpus < Lda::Corpus
  end
  
end