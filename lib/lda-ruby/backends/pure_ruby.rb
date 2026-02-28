# frozen_string_literal: true

module Lda
  module Backends
    class PureRuby < Base
      MIN_PROBABILITY = 1e-12

      def initialize(random_seed: nil)
        super(random_seed: random_seed)
        @beta_probabilities = nil
        @beta_log = nil
        @gamma = nil
        @phi = nil
        @topic_weights_kernel = nil
        @topic_term_accumulator_kernel = nil
        @document_inference_kernel = nil
        @corpus_iteration_kernel = nil
        @topic_term_finalizer_kernel = nil
        @gamma_shift_kernel = nil
        @topic_document_probability_kernel = nil
        @topic_term_seed_kernel = nil
        @trusted_kernel_outputs = false
      end

      attr_writer :topic_weights_kernel,
                  :topic_term_accumulator_kernel,
                  :document_inference_kernel,
                  :corpus_iteration_kernel,
                  :topic_term_finalizer_kernel,
                  :gamma_shift_kernel,
                  :topic_document_probability_kernel,
                  :topic_term_seed_kernel,
                  :trusted_kernel_outputs

      def name
        "pure_ruby"
      end

      def corpus=(corpus)
        super
        @beta_probabilities = nil
        @beta_log = nil
        @gamma = nil
        @phi = nil
        true
      end

      def em(start)
        em_input = build_em_input(start)
        return nil if em_input.nil?

        run_em_iterations(em_input)
        nil
      end

      # Returns an EM input snapshot that can be reused by Rust orchestration
      # and Ruby fallback paths without re-sampling random initialization.
      def rust_em_input(start)
        build_em_input(start)
      end

      def em_from_input(em_input)
        return nil if em_input.nil?

        run_em_iterations(em_input)
        nil
      end

      def apply_em_state(beta_probabilities:, beta_log:, gamma:, phi:)
        @beta_probabilities = beta_probabilities
        @beta_log = beta_log
        @gamma = gamma
        @phi = phi

        nil
      end

      def beta
        @beta_log || []
      end

      def gamma
        @gamma || []
      end

      def compute_phi
        clone_matrix(@phi || [])
      end

      def model
        [Integer(num_topics), max_term_index + 1, Float(init_alpha)]
      end

      def topic_document_probability(phi_matrix, document_counts)
        kernel_output = nil
        if @topic_document_probability_kernel
          kernel_output = @topic_document_probability_kernel.call(
            phi_matrix,
            document_counts,
            Integer(num_topics),
            MIN_PROBABILITY
          )
        end

        if valid_topic_document_probability_output?(kernel_output, document_counts.size, Integer(num_topics))
          if @trusted_kernel_outputs
            kernel_output
          else
            kernel_output.map { |row| row.map(&:to_f) }
          end
        else
          default_topic_document_probability(phi_matrix, document_counts)
        end
      rescue StandardError
        default_topic_document_probability(phi_matrix, document_counts)
      end

      private

      def build_em_input(start)
        return nil if @corpus.nil? || @corpus.num_docs.zero?

        topics = Integer(num_topics)
        raise ArgumentError, "num_topics must be greater than zero" if topics <= 0

        terms = max_term_index + 1
        raise ArgumentError, "corpus must contain terms" if terms <= 0

        document_words = @corpus.documents.map { |document| document.words.map(&:to_i) }
        document_counts = @corpus.documents.map { |document| document.counts.map(&:to_f) }

        initial_beta_probabilities =
          if start.to_s.strip.casecmp("seeded").zero? || start.to_s.strip.casecmp("deterministic").zero?
            seeded_topic_term_probabilities(topics, terms, document_words, document_counts)
          else
            initial_topic_term_probabilities(topics, terms)
          end

        {
          topics: topics,
          terms: terms,
          document_words: document_words,
          document_counts: document_counts,
          document_totals: document_counts.map { |counts| counts.sum.to_f },
          document_lengths: document_words.map(&:length),
          initial_beta_probabilities: initial_beta_probabilities,
          min_probability: MIN_PROBABILITY
        }
      end

      def run_em_iterations(em_input)
        topics = em_input.fetch(:topics)
        terms = em_input.fetch(:terms)
        document_words = em_input.fetch(:document_words)
        document_counts = em_input.fetch(:document_counts)
        document_totals = em_input.fetch(:document_totals)
        document_lengths = em_input.fetch(:document_lengths)

        @beta_probabilities = em_input.fetch(:initial_beta_probabilities)
        previous_gamma = nil

        Integer(em_max_iter).times do
          if @trusted_kernel_outputs && @corpus_iteration_kernel
            current_gamma, current_phi, topic_term_counts = infer_corpus_iteration(
              nil,
              document_words,
              document_counts,
              document_totals,
              document_lengths,
              topics,
              terms
            )
          else
            topic_term_counts = Array.new(topics) { Array.new(terms, MIN_PROBABILITY) }
            current_gamma, current_phi, topic_term_counts = infer_corpus_iteration(
              topic_term_counts,
              document_words,
              document_counts,
              document_totals,
              document_lengths,
              topics,
              terms
            )
          end

          @beta_probabilities, @beta_log = finalize_topic_term_counts(topic_term_counts)
          @gamma = current_gamma
          @phi = current_phi

          break if previous_gamma && average_gamma_shift(previous_gamma, current_gamma) <= Float(em_convergence)

          previous_gamma = current_gamma
        end
      end

      def max_term_index
        return -1 if @corpus.nil? || @corpus.documents.empty?

        @corpus.documents
          .flat_map(&:words)
          .max || -1
      end

      def initial_topic_term_probabilities(topics, terms)
        Array.new(topics) do
          weights = Array.new(terms) { @random.rand + MIN_PROBABILITY }
          normalize!(weights)
        end
      end

      def seeded_topic_term_probabilities(topics, terms, document_words, document_counts)
        kernel_output = nil
        if @topic_term_seed_kernel
          kernel_output = @topic_term_seed_kernel.call(
            document_words,
            document_counts,
            Integer(topics),
            Integer(terms),
            MIN_PROBABILITY
          )
        end

        if valid_seeded_topic_term_probabilities?(kernel_output, topics, terms)
          if @trusted_kernel_outputs
            kernel_output
          else
            kernel_output.map { |weights| normalize!(weights.map(&:to_f)) }
          end
        else
          default_seeded_topic_term_probabilities(topics, terms, document_words, document_counts)
        end
      rescue StandardError
        default_seeded_topic_term_probabilities(topics, terms, document_words, document_counts)
      end

      def valid_seeded_topic_term_probabilities?(matrix, expected_topics, expected_terms)
        return false unless matrix.is_a?(Array)
        return false unless matrix.size == expected_topics

        matrix.each do |row|
          return false unless row.is_a?(Array)
          return false unless row.size == expected_terms
          row.each do |value|
            return false unless value.is_a?(Numeric)
            return false unless value.finite?
          end
        end

        true
      end

      def default_seeded_topic_term_probabilities(topics, terms, document_words, document_counts)
        topic_term_counts = Array.new(topics) { Array.new(terms, MIN_PROBABILITY) }

        document_words.each_with_index do |words, document_index|
          topic_index = document_index % topics
          counts = document_counts[document_index] || []

          words.each_with_index do |word_index, word_offset|
            next if word_index >= terms

            topic_term_counts[topic_index][word_index] += counts[word_offset].to_f
          end
        end

        topic_term_counts.map { |weights| normalize!(weights) }
      end

      def topic_weights_for_word(word_index, gamma_d)
        kernel_weights = nil
        if @topic_weights_kernel
          kernel_weights = @topic_weights_kernel.call(@beta_probabilities, gamma_d, Integer(word_index), MIN_PROBABILITY)
        end

        weights =
          if valid_topic_weights?(kernel_weights, gamma_d.length)
            kernel_weights.map(&:to_f)
          else
            default_topic_weights_for_word(word_index, gamma_d)
          end

        normalize!(weights)
      rescue StandardError
        normalize!(default_topic_weights_for_word(word_index, gamma_d))
      end

      def valid_topic_weights?(weights, expected_size)
        weights.is_a?(Array) && weights.size == expected_size
      end

      def default_topic_weights_for_word(word_index, gamma_d)
        topics = gamma_d.length

        Array.new(topics) do |topic_index|
          @beta_probabilities[topic_index][word_index] * [gamma_d[topic_index], MIN_PROBABILITY].max
        end
      end

      def infer_document(gamma_initial, phi_initial, words, counts)
        kernel_output = nil

        if @document_inference_kernel
          kernel_output = @document_inference_kernel.call(
            @beta_probabilities,
            gamma_initial,
            words.map(&:to_i),
            counts.map(&:to_f),
            Integer(max_iter),
            Float(convergence),
            MIN_PROBABILITY,
            Float(init_alpha)
          )
        end

        if valid_document_inference_output?(kernel_output, gamma_initial.length, phi_initial.length)
          if @trusted_kernel_outputs
            [kernel_output[0], kernel_output[1]]
          else
            gamma_out = kernel_output[0].map(&:to_f)
            phi_out = kernel_output[1].map { |row| normalize!(row.map(&:to_f)) }
            [gamma_out, phi_out]
          end
        else
          default_infer_document(gamma_initial, phi_initial, words, counts)
        end
      rescue StandardError
        default_infer_document(gamma_initial, phi_initial, words, counts)
      end

      def valid_document_inference_output?(output, expected_topics, expected_length)
        return false unless output.is_a?(Array)
        return false unless output.size == 2

        gamma_out = output[0]
        phi_out = output[1]

        return false unless gamma_out.is_a?(Array) && gamma_out.size == expected_topics
        return false unless phi_out.is_a?(Array) && phi_out.size == expected_length

        phi_out.all? { |row| row.is_a?(Array) && row.size == expected_topics }
      end

      def default_infer_document(gamma_initial, phi_initial, words, counts)
        topics = gamma_initial.length
        gamma_d = gamma_initial.dup
        phi_d = phi_initial

        Integer(max_iter).times do
          gamma_next = Array.new(topics, Float(init_alpha))

          words.each_with_index do |word_index, word_offset|
            topic_weights = topic_weights_for_word(word_index, gamma_d)
            phi_d[word_offset] = topic_weights

            count = counts[word_offset].to_f
            topics.times do |topic_index|
              gamma_next[topic_index] += count * topic_weights[topic_index]
            end
          end

          gamma_shift = max_absolute_distance(gamma_d, gamma_next)
          gamma_d = gamma_next
          break if gamma_shift <= Float(convergence)
        end

        [gamma_d, phi_d]
      end

      def infer_corpus_iteration(
        topic_term_counts_initial,
        document_words,
        document_counts,
        document_totals,
        document_lengths,
        topics,
        terms
      )
        topic_term_counts_fallback =
          topic_term_counts_initial || Array.new(topics) { Array.new(terms, MIN_PROBABILITY) }
        kernel_output = nil

        if @corpus_iteration_kernel
          kernel_output = @corpus_iteration_kernel.call(
            @beta_probabilities,
            document_words,
            document_counts,
            Integer(max_iter),
            Float(convergence),
            MIN_PROBABILITY,
            Float(init_alpha)
          )
        end

        if valid_corpus_iteration_output?(kernel_output, document_words.size, document_lengths, topics, terms)
          if @trusted_kernel_outputs
            [kernel_output[0], kernel_output[1], kernel_output[2]]
          else
            current_gamma = kernel_output[0].map { |row| row.map(&:to_f) }
            current_phi = kernel_output[1].map do |doc_phi|
              doc_phi.map { |row| normalize!(row.map(&:to_f)) }
            end
            topic_term_counts = kernel_output[2].map { |row| row.map(&:to_f) }

            [current_gamma, current_phi, topic_term_counts]
          end
        else
          default_infer_corpus_iteration(
            topic_term_counts_fallback,
            document_words,
            document_counts,
            document_totals,
            topics
          )
        end
      rescue StandardError
        default_infer_corpus_iteration(
          topic_term_counts_fallback,
          document_words,
          document_counts,
          document_totals,
          topics
        )
      end

      def valid_corpus_iteration_output?(output, expected_docs, expected_lengths, expected_topics, expected_terms)
        return false unless output.is_a?(Array)
        return false unless output.size == 3

        gamma_matrix = output[0]
        phi_tensor = output[1]
        topic_term_counts = output[2]

        return false unless gamma_matrix.is_a?(Array) && gamma_matrix.size == expected_docs
        return false unless phi_tensor.is_a?(Array) && phi_tensor.size == expected_docs
        return false unless topic_term_counts.is_a?(Array) && topic_term_counts.size == expected_topics

        gamma_matrix.each do |row|
          return false unless row.is_a?(Array) && row.size == expected_topics
        end

        phi_tensor.each_with_index do |doc_phi, index|
          return false unless doc_phi.is_a?(Array) && doc_phi.size == expected_lengths[index]
          doc_phi.each do |row|
            return false unless row.is_a?(Array) && row.size == expected_topics
          end
        end

        topic_term_counts.each do |row|
          return false unless row.is_a?(Array) && row.size == expected_terms
        end

        true
      end

      def default_infer_corpus_iteration(
        topic_term_counts_initial,
        document_words,
        document_counts,
        document_totals,
        topics
      )
        topic_term_counts = topic_term_counts_initial
        current_gamma = Array.new(document_words.size) { Array.new(topics, Float(init_alpha)) }
        current_phi = Array.new(document_words.size)

        document_words.each_with_index do |words, document_index|
          counts = document_counts[document_index]
          total = document_totals[document_index].to_f

          gamma_d = Array.new(topics, Float(init_alpha) + (total / topics))
          phi_d = Array.new(words.length) { Array.new(topics, 1.0 / topics) }

          gamma_d, phi_d = infer_document(gamma_d, phi_d, words, counts)

          current_gamma[document_index] = gamma_d
          current_phi[document_index] = phi_d
          topic_term_counts = accumulate_topic_term_counts(topic_term_counts, phi_d, words, counts)
        end

        [current_gamma, current_phi, topic_term_counts]
      end

      def accumulate_topic_term_counts(topic_term_counts, phi_d, words, counts)
        kernel_counts = nil
        if @topic_term_accumulator_kernel
          kernel_counts = @topic_term_accumulator_kernel.call(
            topic_term_counts,
            phi_d,
            words.map(&:to_i),
            counts.map(&:to_f)
          )
        end

        if valid_topic_term_counts?(kernel_counts, topic_term_counts)
          kernel_counts
        else
          default_accumulate_topic_term_counts(topic_term_counts, phi_d, words, counts)
        end
      rescue StandardError
        default_accumulate_topic_term_counts(topic_term_counts, phi_d, words, counts)
      end

      def valid_topic_term_counts?(candidate, reference)
        return false unless candidate.is_a?(Array)
        return false unless candidate.size == reference.size

        candidate.each_with_index do |row, index|
          return false unless row.is_a?(Array)
          return false unless row.size == reference[index].size
        end

        true
      end

      def default_accumulate_topic_term_counts(topic_term_counts, phi_d, words, counts)
        topics = topic_term_counts.size

        words.each_with_index do |word_index, word_offset|
          count = counts[word_offset].to_f
          next if count.zero?

          topics.times do |topic_index|
            topic_term_counts[topic_index][word_index] += count * phi_d[word_offset][topic_index]
          end
        end

        topic_term_counts
      end

      def finalize_topic_term_counts(topic_term_counts)
        kernel_output = nil
        if @topic_term_finalizer_kernel
          kernel_output = @topic_term_finalizer_kernel.call(topic_term_counts, MIN_PROBABILITY)
        end

        if valid_topic_term_finalization_output?(kernel_output, topic_term_counts)
          if @trusted_kernel_outputs
            [kernel_output[0], kernel_output[1]]
          else
            beta_probabilities = kernel_output[0].map { |row| row.map(&:to_f) }
            beta_log = kernel_output[1].map { |row| row.map(&:to_f) }
            [beta_probabilities, beta_log]
          end
        else
          default_finalize_topic_term_counts(topic_term_counts)
        end
      rescue StandardError
        default_finalize_topic_term_counts(topic_term_counts)
      end

      def valid_topic_term_finalization_output?(output, topic_term_counts)
        return false unless output.is_a?(Array)
        return false unless output.size == 2

        beta_probabilities = output[0]
        beta_log = output[1]
        return false unless beta_probabilities.is_a?(Array) && beta_log.is_a?(Array)
        return false unless beta_probabilities.size == topic_term_counts.size
        return false unless beta_log.size == topic_term_counts.size

        beta_probabilities.each_with_index do |row, index|
          return false unless row.is_a?(Array)
          return false unless row.size == topic_term_counts[index].size
        end

        beta_log.each_with_index do |row, index|
          return false unless row.is_a?(Array)
          return false unless row.size == topic_term_counts[index].size
        end

        true
      end

      def default_finalize_topic_term_counts(topic_term_counts)
        beta_probabilities = topic_term_counts.map { |weights| normalize!(weights) }
        beta_log = beta_probabilities.map do |topic_weights|
          topic_weights.map { |probability| Math.log([probability, MIN_PROBABILITY].max) }
        end

        [beta_probabilities, beta_log]
      end

      def valid_topic_document_probability_output?(output, expected_docs, expected_topics)
        return false unless output.is_a?(Array)
        return false unless output.size == expected_docs

        output.each do |row|
          return false unless row.is_a?(Array)
          return false unless row.size == expected_topics
          row.each do |value|
            return false unless value.is_a?(Numeric)
            return false unless value.finite?
          end
        end

        true
      end

      def default_topic_document_probability(phi_matrix, document_counts)
        topics = Integer(num_topics)
        output = []

        document_counts.each_with_index do |counts, doc_index|
          tops = Array.new(topics, 0.0)
          ttl = counts.inject(0.0) { |sum, value| sum + value.to_f }
          doc_phi = phi_matrix[doc_index] || []

          doc_phi.each_with_index do |word_dist, word_idx|
            count = counts[word_idx].to_f
            next if count.zero?

            topics.times do |topic_idx|
              top_prob = word_dist[topic_idx].to_f
              tops[topic_idx] += Math.log([top_prob, MIN_PROBABILITY].max) * count
            end
          end

          tops = tops.map { |value| value / ttl } if ttl.positive?
          output << tops
        end

        output
      end

      def max_absolute_distance(left, right)
        left.zip(right).map { |a, b| (a - b).abs }.max.to_f
      end

      def average_gamma_shift(previous_gamma, current_gamma)
        kernel_shift = nil
        if @gamma_shift_kernel
          kernel_shift = @gamma_shift_kernel.call(previous_gamma, current_gamma)
        end

        if kernel_shift.is_a?(Numeric) && kernel_shift.finite? && kernel_shift >= 0.0
          kernel_shift.to_f
        else
          default_average_gamma_shift(previous_gamma, current_gamma)
        end
      rescue StandardError
        default_average_gamma_shift(previous_gamma, current_gamma)
      end

      def default_average_gamma_shift(previous_gamma, current_gamma)
        deltas = []

        previous_gamma.each_with_index do |previous_row, row_index|
          previous_row.each_with_index do |previous_value, col_index|
            deltas << (previous_value - current_gamma[row_index][col_index]).abs
          end
        end

        return 0.0 if deltas.empty?

        deltas.sum / deltas.size.to_f
      end
    end
  end
end
