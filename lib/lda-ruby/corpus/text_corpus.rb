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
      docs = YAML.load_file(@filename)
      docs.each do |doc|
        add_document(TextDocument.new(self, doc))
      end
    end
  end
end
