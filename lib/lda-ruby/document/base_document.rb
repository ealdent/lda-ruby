module Lda
  class BaseDocument
    def words
      raise NotSupportedError
    end

    def length
      raise NotSupportedError
    end

    def total
      raise NotSupportedError
    end
  end
end