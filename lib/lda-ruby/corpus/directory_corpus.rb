module Lda
  class DirectoryCorpus < TextCorpus
    attr_reader :path, :extension

    def initialize(path, extension = nil)
      @path = path.dup.freeze
      @extension = extension

      super(nil)

      load_from_directory
    end

    protected

    def load_from_directory
      dir_glob = File.join(@path, (@extension ? "*.#{@extension}" : "*"))

      Dir.glob(dir_glob).each do |filename|
        puts "[debug] Loading document #{filename}."
        add_document(TextDocument.build_from_file(self, filename))
      end
    end
  end
end