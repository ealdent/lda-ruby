# frozen_string_literal: true

require "lda-ruby/backends/base"
require "lda-ruby/backends/native"
require "lda-ruby/backends/pure_ruby"

module Lda
  module Backends
    class << self
      def build(host:, requested: nil, random_seed: nil)
        mode = normalize_mode(requested)

        case mode
        when :auto
          if Native.available?(host)
            Native.new(host, random_seed: random_seed)
          else
            PureRuby.new(random_seed: random_seed)
          end
        when :native
          raise LoadError, "Native backend is unavailable for this environment" unless Native.available?(host)

          Native.new(host, random_seed: random_seed)
        when :pure
          PureRuby.new(random_seed: random_seed)
        else
          raise ArgumentError, "Unknown backend mode: #{requested.inspect}"
        end
      end

      private

      def normalize_mode(requested)
        raw_mode = requested || ENV.fetch("LDA_RUBY_BACKEND", "auto")

        case raw_mode.to_s.strip.downcase
        when "", "auto"
          :auto
        when "native", "c"
          :native
        when "pure", "ruby", "pure_ruby"
          :pure
        else
          raw_mode
        end
      end
    end
  end
end
