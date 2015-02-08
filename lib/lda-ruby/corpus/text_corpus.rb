module Lda
  class TextCorpus < Corpus
    attr_reader :filename

    # Load text documents from YAML file if filename is given.
    def initialize(filename)
      super()
      @filename = filename      
      load_from_file
    end

    protected
    
    def load_from_file
      begin
        docs = YAML.load_file(@filename)
      rescue
        puts "File not available, adding this as text"
      end
      if(!docs.nil?)
        docs.each do |doc|
          add_document(TextDocument.new(self, doc))
        end
      else
        add_document(TextDocument.new(self, @filename))
      end
    end
  end
end
