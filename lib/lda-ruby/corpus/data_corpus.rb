module Lda
  class DataCorpus < Corpus
    attr_reader :filename

    def initialize(filename)
      super()

      @filename = filename
      load_from_file
    end

    protected

    def load_from_file
      txt = File.open(@filename, 'r') { |f| f.read }
      lines = txt.split(/[\r\n]+/)
      lines.each do |line|
        add_document(DataDocument.new(self, line))
      end
    end
  end
end