# frozen_string_literal: true

module Lda
  module Backends
    class Rust < Base
      SETTINGS = %i[max_iter convergence em_max_iter em_convergence num_topics init_alpha est_alpha verbose].freeze

      def self.available?
        return false unless defined?(::Lda::RUST_EXTENSION_LOADED) && ::Lda::RUST_EXTENSION_LOADED
        return false unless defined?(::Lda::RustBackend)

        if ::Lda::RustBackend.respond_to?(:available?)
          ::Lda::RustBackend.available?
        else
          true
        end
      rescue StandardError
        false
      end

      SETTINGS.each do |setting_name|
        define_method(setting_name) do
          @fallback.public_send(setting_name)
        end

        define_method("#{setting_name}=") do |value|
          @fallback.public_send("#{setting_name}=", value)
        end
      end

      def initialize(random_seed: nil)
        super(random_seed: random_seed)
        raise LoadError, "Rust backend is unavailable for this environment" unless self.class.available?

        @fallback = PureRuby.new(random_seed: random_seed)
        @fallback.topic_weights_kernel = method(:rust_topic_weights_for_word)
      end

      def name
        "rust"
      end

      def corpus=(corpus)
        @corpus = corpus
        @fallback.corpus = corpus
        true
      end

      def fast_load_corpus_from_file(filename)
        loaded = @fallback.fast_load_corpus_from_file(filename)
        @corpus = @fallback.corpus
        loaded
      end

      def load_settings(settings_file)
        loaded = @fallback.load_settings(settings_file)
        @corpus = @fallback.corpus
        loaded
      end

      def set_config(init_alpha, num_topics, max_iter, convergence, em_max_iter, em_convergence, est_alpha)
        @fallback.set_config(init_alpha, num_topics, max_iter, convergence, em_max_iter, em_convergence, est_alpha)
      end

      def em(start)
        rust_before_em(start)
        @fallback.em(start)
      end

      def beta
        @fallback.beta
      end

      def gamma
        @fallback.gamma
      end

      def compute_phi
        @fallback.compute_phi
      end

      def model
        @fallback.model
      end

      private

      def rust_before_em(start)
        return unless defined?(::Lda::RustBackend)
        return unless ::Lda::RustBackend.respond_to?(:before_em)

        ::Lda::RustBackend.before_em(start.to_s, @corpus&.num_docs.to_i, @corpus&.num_terms.to_i)
      rescue StandardError
        nil
      end

      def rust_topic_weights_for_word(beta_probabilities, gamma, word_index, min_probability)
        return nil unless defined?(::Lda::RustBackend)
        return nil unless ::Lda::RustBackend.respond_to?(:topic_weights_for_word)

        ::Lda::RustBackend.topic_weights_for_word(
          beta_probabilities,
          gamma,
          Integer(word_index),
          Float(min_probability)
        )
      rescue StandardError
        nil
      end
    end
  end
end
