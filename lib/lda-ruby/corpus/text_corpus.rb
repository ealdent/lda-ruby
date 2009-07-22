module Lda
  class TextCorpus < Corpus
    # Load text documents from YAML file if filename is given.
    def initialize(filename = nil)
      super(nil)

      load_from_file(filename) if filename
    end

    def add_document(doc)
      super(doc)
      doc.tokens.each { |w| @vocabulary.check_word(w) } if @vocabulary
    end

    protected

    def regenerate_vocabulary
      @vocabulary = Vocabulary.new
      @documents.map { |d| d.words }.flatten.uniq.each { |w| @vocabulary.check_word(w) }
    end

    def load_from_file(filename)
      docs = YAML.load_file(filename)
      docs.each do |doc|
        add_document(TextDocument.build(self, doc))
      end
    end
  end
end