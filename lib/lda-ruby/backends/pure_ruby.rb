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
      end

      attr_writer :topic_weights_kernel, :topic_term_accumulator_kernel, :document_inference_kernel

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
        return nil if @corpus.nil? || @corpus.num_docs.zero?

        topics = Integer(num_topics)
        raise ArgumentError, "num_topics must be greater than zero" if topics <= 0

        terms = max_term_index + 1
        raise ArgumentError, "corpus must contain terms" if terms <= 0

        @beta_probabilities =
          if start.to_s.strip.casecmp("seeded").zero? || start.to_s.strip.casecmp("deterministic").zero?
            seeded_topic_term_probabilities(topics, terms)
          else
            initial_topic_term_probabilities(topics, terms)
          end

        previous_gamma = nil

        Integer(em_max_iter).times do
          topic_term_counts = Array.new(topics) { Array.new(terms, MIN_PROBABILITY) }
          current_gamma = Array.new(@corpus.num_docs) { Array.new(topics, Float(init_alpha)) }
          current_phi = Array.new(@corpus.num_docs)

          @corpus.documents.each_with_index do |document, document_index|
            gamma_d = Array.new(topics, Float(init_alpha) + (document.total.to_f / topics))
            phi_d = Array.new(document.length) { Array.new(topics, 1.0 / topics) }

            gamma_d, phi_d = infer_document(gamma_d, phi_d, document.words, document.counts)

            current_gamma[document_index] = gamma_d
            current_phi[document_index] = phi_d

            topic_term_counts = accumulate_topic_term_counts(topic_term_counts, phi_d, document.words, document.counts)
          end

          @beta_probabilities = topic_term_counts.map { |weights| normalize!(weights) }
          @gamma = current_gamma
          @phi = current_phi

          break if previous_gamma && average_gamma_shift(previous_gamma, current_gamma) <= Float(em_convergence)

          previous_gamma = clone_matrix(current_gamma)
        end

        @beta_log = @beta_probabilities.map do |topic_weights|
          topic_weights.map { |probability| Math.log([probability, MIN_PROBABILITY].max) }
        end

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

      private

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

      def seeded_topic_term_probabilities(topics, terms)
        topic_term_counts = Array.new(topics) { Array.new(terms, MIN_PROBABILITY) }

        @corpus.documents.each_with_index do |document, document_index|
          topic_index = document_index % topics

          document.words.each_with_index do |word_index, word_offset|
            topic_term_counts[topic_index][word_index] += document.counts[word_offset].to_f
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
          gamma_out = kernel_output[0].map(&:to_f)
          phi_out = kernel_output[1].map { |row| normalize!(row.map(&:to_f)) }
          [gamma_out, phi_out]
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
        phi_d = clone_matrix(phi_initial)

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

      def max_absolute_distance(left, right)
        left.zip(right).map { |a, b| (a - b).abs }.max.to_f
      end

      def average_gamma_shift(previous_gamma, current_gamma)
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
