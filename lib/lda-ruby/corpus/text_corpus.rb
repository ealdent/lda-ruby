module Lda
  class TextCorpus < Corpus
    attr_reader :path

    def initialize(path)
      @path = path.dup.freeze
      super
    end

    protected

    def load_from_directory(path, extension = nil)
      dir_glob = File.join(path, (extension ? "*.#{extension}" : "*"))

      Dir.glob(dir_glob).each do |filename|
        puts "[debug] Loading document #{filename}."
        add_document(TextDocument.build_from_file(filename))
      end
    end
  end
end