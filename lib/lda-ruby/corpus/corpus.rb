require 'set'

module Lda
  class Corpus
    attr_reader :documents, :num_docs, :num_terms

    #
    # Create a blank corpus object.  Either add documents to it
    # using the +add_document+ method or load the data from a file
    # using +load_from_file+.
    #
    def initialize(filename = nil)
      @documents = Array.new
      @all_terms = Set.new
      @num_terms = @num_docs  = 0

      load_from_file(filename) if filename
    end

    # Add a new document to the corpus.  This can either be
    # an svmlight-style formatted line with the first element
    # being the number of words, or it can be a Document object.
    def add_document(doc)
      @documents << if doc.kind_of?(BaseDocument)
        doc
      elsif doc.is_a?(String)
        Document.new(doc)
      else
        raise 'Unrecognized document format.'
      end

      @all_terms += doc.words
      @num_docs += 1
      @num_terms = @all_terms.size

      true
    end

    # Populate this corpus from the data in the file.
    def load_from_file(filename)
      File.open(filename, 'r') do |f|
        f.each do |line|
          self.add_document(line)
        end
      end
      true
    end
  end
end
