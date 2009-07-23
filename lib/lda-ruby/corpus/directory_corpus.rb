module Lda
  class DirectoryCorpus < Corpus
    attr_reader :path, :extension

    # load documents from a directory
    def initialize(path, extension = nil)
      super()

      @path = path.dup.freeze
      @extension = extension ? extension.dup.freeze : nil

      load_from_directory
    end

    protected

    def load_from_directory
      dir_glob = File.join(@path, (@extension ? "*.#{@extension}" : "*"))

      Dir.glob(dir_glob).each do |filename|
        add_document(TextDocument.build_from_file(self, filename))
      end
    end
  end
end