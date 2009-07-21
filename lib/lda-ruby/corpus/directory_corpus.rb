module Lda
  class DirectoryCorpus < Corpus
    attr_reader :path, :extension, :vocabulary

    def initialize(path, extension = nil)
      @path = path.dup.freeze
      @extension = extension
      @vocabulary = Vocabulary.new

      super(nil)

      load_from_directory
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

    def load_from_directory
      dir_glob = File.join(@path, (@extension ? "*.#{@extension}" : "*"))

      Dir.glob(dir_glob).each do |filename|
        puts "[debug] Loading document #{filename}."
        add_document(TextDocument.build_from_file(self, filename))
      end
    end
  end
end