module Lda
  class TextCorpus < Corpus
    attr_reader :path, :extension, :vocabulary

    def initialize(path, extension = nil)
      @path = path.dup.freeze
      @extension = extension

      super(nil)

      load_from_directory
      generate_vocabulary
    end

    def generate_vocabulary
      @vocabulary = Array.new
      @documents.each do |doc|
        @vocabulary << doc.words
      end

      @vocabulary.flatten!
      @vocabulary.uniq!
      @vocabulary.reject! { |w| w.nil? }

      @vocabulary
    end

    protected

    def load_from_directory
      dir_glob = File.join(@path, (@extension ? "*.#{@extension}" : "*"))

      Dir.glob(dir_glob).each do |filename|
        puts "[debug] Loading document #{filename}."
        add_document(TextDocument.build_from_file(filename))
      end
    end
  end
end