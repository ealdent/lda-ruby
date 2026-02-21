# frozen_string_literal: true

module Lda
  module RustBuildPolicy
    ENV_KEY = "LDA_RUBY_RUST_BUILD"
    AUTO = "auto"
    ALWAYS = "always"
    NEVER = "never"
    VALID_VALUES = [AUTO, ALWAYS, NEVER].freeze

    module_function

    def resolve(raw_value = ENV[ENV_KEY])
      value = raw_value.to_s.strip.downcase
      return AUTO if value.empty?
      return value if VALID_VALUES.include?(value)

      AUTO
    end
  end
end
