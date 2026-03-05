# frozen_string_literal: true

module Lda
  module Backends
    class Rust < Base
      SETTINGS = %i[max_iter convergence em_max_iter em_convergence num_topics init_alpha est_alpha verbose].freeze
      MIN_PROBABILITY = 1e-12

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

        @rust_corpus_session_id = nil
        @rust_corpus_terms = nil
        @rust_document_lengths = nil
        @rust_document_words = nil
        @rust_document_counts = nil

        @fallback = PureRuby.new(random_seed: random_seed)
        @fallback.topic_weights_kernel = method(:rust_topic_weights_for_word)
        @fallback.topic_term_accumulator_kernel = method(:rust_accumulate_topic_term_counts)
        @fallback.document_inference_kernel = method(:rust_infer_document)
        @fallback.corpus_iteration_kernel = method(:rust_infer_corpus_iteration)
        @fallback.topic_term_finalizer_kernel = method(:rust_finalize_topic_term_counts)
        @fallback.gamma_shift_kernel = method(:rust_average_gamma_shift)
        @fallback.topic_document_probability_kernel = method(:rust_topic_document_probability)
        @fallback.topic_term_seed_kernel = method(:rust_seeded_topic_term_probabilities)
        @fallback.trusted_kernel_outputs = true
      end

      def name
        "rust"
      end

      def corpus=(corpus)
        previous_session_id = @rust_corpus_session_id
        @corpus = corpus
        @fallback.corpus = corpus
        register_rust_corpus_session(previous_session_id)
        true
      end

      def fast_load_corpus_from_file(filename)
        loaded = @fallback.fast_load_corpus_from_file(filename)
        self.corpus = @fallback.corpus
        loaded
      end

      def load_settings(settings_file)
        loaded = @fallback.load_settings(settings_file)
        self.corpus = @fallback.corpus
        loaded
      end

      def set_config(init_alpha, num_topics, max_iter, convergence, em_max_iter, em_convergence, est_alpha)
        @fallback.set_config(init_alpha, num_topics, max_iter, convergence, em_max_iter, em_convergence, est_alpha)
      end

      def em(start)
        start_mode = start.to_s
        rust_before_em(start_mode)
        return nil if rust_orchestrated_em(start_mode)

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

      def rust_orchestrated_em(start)
        session_orchestrated = rust_orchestrated_em_with_session(start)
        return true if session_orchestrated

        direct_orchestrated = rust_orchestrated_em_with_start_seed(start)
        return true if direct_orchestrated

        rust_orchestrated_em_with_beta(start)
      end

      def rust_orchestrated_em_with_session(start)
        return false unless defined?(::Lda::RustBackend)
        return false unless ::Lda::RustBackend.respond_to?(:run_em_on_session)
        return false unless ensure_rust_corpus_session

        random_seed = Integer(next_random_seed)
        if @rust_corpus_session_id
          output = ::Lda::RustBackend.run_em_on_session(
            Integer(@rust_corpus_session_id),
            start.to_s,
            *current_rust_session_config_signature,
            random_seed
          )

          if valid_rust_em_output?(output, @rust_document_lengths, Integer(num_topics), Integer(@rust_corpus_terms))
            beta_probabilities, beta_log, gamma, phi = output
            @fallback.apply_em_state(
              beta_probabilities: beta_probabilities,
              beta_log: beta_log,
              gamma: gamma,
              phi: phi
            )
            return true
          end
        end

        return false unless ::Lda::RustBackend.respond_to?(:run_em_on_session_with_corpus)

        managed_output = ::Lda::RustBackend.run_em_on_session_with_corpus(
          Integer(@rust_corpus_session_id || 0),
          @rust_document_words,
          @rust_document_counts,
          Integer(@rust_corpus_terms),
          start.to_s,
          *current_rust_session_config_signature,
          random_seed
        )

        return false unless managed_output.is_a?(Array) && managed_output.size == 5

        session_id, beta_probabilities, beta_log, gamma, phi = managed_output
        return false unless session_id.is_a?(Numeric) && session_id.positive?

        output = [beta_probabilities, beta_log, gamma, phi]
        return false unless valid_rust_em_output?(output, @rust_document_lengths, Integer(num_topics), Integer(@rust_corpus_terms))

        @rust_corpus_session_id = Integer(session_id)
        @fallback.apply_em_state(
          beta_probabilities: beta_probabilities,
          beta_log: beta_log,
          gamma: gamma,
          phi: phi
        )
        true
      rescue StandardError
        false
      end

      def rust_orchestrated_em_with_start_seed(start)
        return false unless defined?(::Lda::RustBackend)
        return false unless ::Lda::RustBackend.respond_to?(:run_em_with_start_seed)

        em_input = rust_em_corpus_input
        return false if em_input.nil?

        random_seed = Integer(next_random_seed)
        output = ::Lda::RustBackend.run_em_with_start_seed(
          start.to_s,
          em_input.fetch(:document_words),
          em_input.fetch(:document_counts),
          Integer(em_input.fetch(:topics)),
          Integer(em_input.fetch(:terms)),
          Integer(max_iter),
          Float(convergence),
          Integer(em_max_iter),
          Float(em_convergence),
          Float(init_alpha),
          Float(em_input.fetch(:min_probability)),
          random_seed
        )

        return false unless valid_rust_em_output?(
          output,
          em_input.fetch(:document_lengths),
          em_input.fetch(:topics),
          em_input.fetch(:terms)
        )

        beta_probabilities, beta_log, gamma, phi = output
        @fallback.apply_em_state(
          beta_probabilities: beta_probabilities,
          beta_log: beta_log,
          gamma: gamma,
          phi: phi
        )
        true
      rescue StandardError
        false
      end

      def rust_orchestrated_em_with_beta(start)
        return false unless defined?(::Lda::RustBackend)
        return false unless ::Lda::RustBackend.respond_to?(:run_em)

        em_input = @fallback.rust_em_input(start)
        return true if em_input.nil?

        output = ::Lda::RustBackend.run_em(
          em_input.fetch(:initial_beta_probabilities),
          em_input.fetch(:document_words),
          em_input.fetch(:document_counts),
          Integer(max_iter),
          Float(convergence),
          Integer(em_max_iter),
          Float(em_convergence),
          Float(init_alpha),
          Float(em_input.fetch(:min_probability))
        )

        unless valid_rust_em_output?(
          output,
          em_input.fetch(:document_lengths),
          em_input.fetch(:topics),
          em_input.fetch(:terms)
        )
          @fallback.em_from_input(em_input)
          return true
        end

        beta_probabilities, beta_log, gamma, phi = output
        @fallback.apply_em_state(
          beta_probabilities: beta_probabilities,
          beta_log: beta_log,
          gamma: gamma,
          phi: phi
        )
        true
      rescue StandardError
        if defined?(em_input) && em_input
          @fallback.em_from_input(em_input)
          return true
        end

        false
      end

      def rust_em_corpus_input
        return nil if @corpus.nil? || @corpus.num_docs.zero?

        topics = Integer(num_topics)
        raise ArgumentError, "num_topics must be greater than zero" if topics <= 0

        terms = max_term_index + 1
        raise ArgumentError, "corpus must contain terms" if terms <= 0

        document_words = @corpus.documents.map { |document| document.words.map(&:to_i) }
        document_counts = @corpus.documents.map { |document| document.counts.map(&:to_f) }

        {
          topics: topics,
          terms: terms,
          document_words: document_words,
          document_counts: document_counts,
          document_lengths: document_words.map(&:length),
          min_probability: MIN_PROBABILITY
        }
      end

      def max_term_index
        return -1 if @corpus.nil? || @corpus.documents.empty?

        @corpus.documents
          .flat_map(&:words)
          .max || -1
      end

      def register_rust_corpus_session(previous_session_id = nil)
        @rust_corpus_session_id = nil
        @rust_corpus_terms = nil
        @rust_document_lengths = nil
        @rust_document_words = nil
        @rust_document_counts = nil

        if @corpus.nil?
          drop_rust_corpus_session_by_id(previous_session_id)
          return
        end

        return unless defined?(::Lda::RustBackend)

        em_input = rust_em_corpus_input
        if em_input.nil?
          drop_rust_corpus_session_by_id(previous_session_id)
          return
        end

        @rust_corpus_terms = Integer(em_input.fetch(:terms))
        @rust_document_lengths = em_input.fetch(:document_lengths)
        @rust_document_words = em_input.fetch(:document_words)
        @rust_document_counts = em_input.fetch(:document_counts)

        session_id =
          if ::Lda::RustBackend.respond_to?(:replace_corpus_session)
            ::Lda::RustBackend.replace_corpus_session(
              Integer(previous_session_id || 0),
              @rust_document_words,
              @rust_document_counts,
              Integer(@rust_corpus_terms)
            )
          elsif ::Lda::RustBackend.respond_to?(:create_corpus_session)
            drop_rust_corpus_session_by_id(previous_session_id)
            ::Lda::RustBackend.create_corpus_session(
              @rust_document_words,
              @rust_document_counts,
              Integer(@rust_corpus_terms)
            )
          end

        unless session_id.is_a?(Numeric) && session_id.positive?
          drop_rust_corpus_session_by_id(previous_session_id)
          return
        end

        @rust_corpus_session_id = Integer(session_id)
      rescue StandardError
        @rust_corpus_session_id = nil
        @rust_corpus_terms = nil
        @rust_document_lengths = nil
        @rust_document_words = nil
        @rust_document_counts = nil
        drop_rust_corpus_session_by_id(previous_session_id)
      end

      def ensure_rust_corpus_session
        has_session_data = @rust_corpus_terms && @rust_document_lengths && @rust_document_words && @rust_document_counts
        return true if has_session_data

        register_rust_corpus_session(@rust_corpus_session_id)
        @rust_corpus_terms && @rust_document_lengths && @rust_document_words && @rust_document_counts
      rescue StandardError
        false
      end

      def release_rust_corpus_session
        session_id = @rust_corpus_session_id

        @rust_corpus_session_id = nil
        @rust_corpus_terms = nil
        @rust_document_lengths = nil
        @rust_document_words = nil
        @rust_document_counts = nil

        drop_rust_corpus_session_by_id(session_id)
      rescue StandardError
        nil
      end

      def drop_rust_corpus_session_by_id(session_id)
        return unless session_id
        return unless defined?(::Lda::RustBackend)
        return unless ::Lda::RustBackend.respond_to?(:drop_corpus_session)

        ::Lda::RustBackend.drop_corpus_session(Integer(session_id))
      rescue StandardError
        nil
      end

      def current_rust_session_config_signature
        [
          Integer(num_topics),
          Integer(max_iter),
          Float(convergence),
          Integer(em_max_iter),
          Float(em_convergence),
          Float(init_alpha),
          MIN_PROBABILITY
        ]
      end

      def valid_rust_em_output?(output, document_lengths, topics, terms)
        return false unless output.is_a?(Array)
        return false unless output.size == 4

        beta_probabilities, beta_log, gamma, phi = output

        valid_topic_term_matrix?(beta_probabilities, topics, terms) &&
          valid_topic_term_matrix?(beta_log, topics, terms) &&
          valid_gamma_matrix?(gamma, document_lengths.size, topics) &&
          valid_phi_tensor?(phi, document_lengths, topics)
      end

      def valid_topic_term_matrix?(matrix, topics, terms)
        return false unless matrix.is_a?(Array)
        return false unless matrix.size == topics

        matrix.all? do |row|
          row.is_a?(Array) &&
            row.size == terms &&
            row.all? { |value| finite_numeric?(value) }
        end
      end

      def valid_gamma_matrix?(gamma, expected_docs, topics)
        return false unless gamma.is_a?(Array)
        return false unless gamma.size == expected_docs

        gamma.all? do |row|
          row.is_a?(Array) &&
            row.size == topics &&
            row.all? { |value| finite_numeric?(value) && value.positive? }
        end
      end

      def valid_phi_tensor?(phi, document_lengths, topics)
        return false unless phi.is_a?(Array)
        return false unless phi.size == document_lengths.size

        phi.each_with_index.all? do |doc_phi, doc_index|
          doc_phi.is_a?(Array) &&
            doc_phi.size == document_lengths[doc_index] &&
            doc_phi.all? do |row|
              row.is_a?(Array) &&
                row.size == topics &&
                row.all? { |value| finite_numeric?(value) }
            end
        end
      end

      def finite_numeric?(value)
        value.is_a?(Numeric) && value.finite?
      end

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

      def rust_accumulate_topic_term_counts(topic_term_counts, phi_d, words, counts)
        return nil unless defined?(::Lda::RustBackend)
        return nil unless ::Lda::RustBackend.respond_to?(:accumulate_topic_term_counts)

        ::Lda::RustBackend.accumulate_topic_term_counts(
          topic_term_counts,
          phi_d,
          words,
          counts
        )
      rescue StandardError
        nil
      end

      def rust_infer_document(beta_probabilities, gamma_initial, words, counts, max_iter, convergence, min_probability, init_alpha)
        return nil unless defined?(::Lda::RustBackend)
        return nil unless ::Lda::RustBackend.respond_to?(:infer_document)

        output = ::Lda::RustBackend.infer_document(
          beta_probabilities,
          gamma_initial,
          words,
          counts,
          Integer(max_iter),
          Float(convergence),
          Float(min_probability),
          Float(init_alpha)
        )

        return nil unless output.is_a?(Array)
        return nil if output.empty?

        gamma = output.first
        phi_rows = output[1..] || []
        [gamma, phi_rows]
      rescue StandardError
        nil
      end

      def rust_infer_corpus_iteration(beta_probabilities, document_words, document_counts, max_iter, convergence, min_probability, init_alpha)
        return nil unless defined?(::Lda::RustBackend)
        return nil unless ::Lda::RustBackend.respond_to?(:infer_corpus_iteration)

        ::Lda::RustBackend.infer_corpus_iteration(
          beta_probabilities,
          document_words,
          document_counts,
          Integer(max_iter),
          Float(convergence),
          Float(min_probability),
          Float(init_alpha)
        )
      rescue StandardError
        nil
      end

      def rust_finalize_topic_term_counts(topic_term_counts, min_probability)
        return nil unless defined?(::Lda::RustBackend)
        return nil unless ::Lda::RustBackend.respond_to?(:normalize_topic_term_counts)

        ::Lda::RustBackend.normalize_topic_term_counts(
          topic_term_counts,
          Float(min_probability)
        )
      rescue StandardError
        nil
      end

      def rust_average_gamma_shift(previous_gamma, current_gamma)
        return nil unless defined?(::Lda::RustBackend)
        return nil unless ::Lda::RustBackend.respond_to?(:average_gamma_shift)

        ::Lda::RustBackend.average_gamma_shift(previous_gamma, current_gamma)
      rescue StandardError
        nil
      end

      def rust_topic_document_probability(phi_matrix, document_counts, num_topics, min_probability)
        return nil unless defined?(::Lda::RustBackend)
        return nil unless ::Lda::RustBackend.respond_to?(:topic_document_probability)

        ::Lda::RustBackend.topic_document_probability(
          phi_matrix,
          document_counts,
          Integer(num_topics),
          Float(min_probability)
        )
      rescue StandardError
        nil
      end

      def rust_seeded_topic_term_probabilities(document_words, document_counts, topics, terms, min_probability)
        return nil unless defined?(::Lda::RustBackend)
        return nil unless ::Lda::RustBackend.respond_to?(:seeded_topic_term_probabilities)

        ::Lda::RustBackend.seeded_topic_term_probabilities(
          document_words,
          document_counts,
          Integer(topics),
          Integer(terms),
          Float(min_probability)
        )
      rescue StandardError
        nil
      end
    end
  end
end
