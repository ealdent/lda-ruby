module Lda
  class TextCorpus < Corpus
    attr_reader :filename

    # Loads text documents from a YAML file or an array of strings
    def initialize(input_data)
      super()

      docs = if input_data.is_a?(String) && File.exists?(input_data)
        # yaml file containing an array of strings representing each document
        YAML.load_file(input_data)
      elsif input_data.is_a?(Array)
        # an array of strings representing each document
        input_data.dup
      elsif input_data.is_a?(String)
        # a single string representing one document
        [input_data]
      else
        raise "Unknown input type: please pass in a valid filename or an array of strings."
      end

      docs.each do |doc|
        add_document(TextDocument.new(self, doc))
      end
    end
  end
end
