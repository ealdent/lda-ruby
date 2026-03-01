# frozen_string_literal: true

module Lda
  module Backends
    class Base
      attr_reader :corpus

      attr_accessor :max_iter,
                    :convergence,
                    :em_max_iter,
                    :em_convergence,
                    :num_topics,
                    :init_alpha,
                    :est_alpha,
                    :verbose

      def initialize(random_seed: nil)
        @random = random_seed.nil? ? Random.new : Random.new(random_seed)

        @max_iter = 20
        @convergence = 1e-6
        @em_max_iter = 100
        @em_convergence = 1e-4
        @num_topics = 20
        @init_alpha = 0.3
        @est_alpha = 1
        @verbose = true

        @corpus = nil
      end

      def name
        self.class.name.split("::").last.downcase
      end

      def corpus=(corpus)
        @corpus = corpus
        true
      end

      def fast_load_corpus_from_file(filename)
        self.corpus = Lda::DataCorpus.new(filename)
      end

      def load_settings(settings_file)
        File.readlines(settings_file).each do |line|
          next if line.strip.empty? || line.strip.start_with?("#")

          key, value = line.split(/\s+/, 2)
          next if value.nil?

          case key.downcase
          when "max_iter", "var_max_iter"
            self.max_iter = value.to_i
          when "convergence", "var_converged"
            self.convergence = value.to_f
          when "em_max_iter"
            self.em_max_iter = value.to_i
          when "em_convergence", "em_converged"
            self.em_convergence = value.to_f
          when "num_topics", "ntopics"
            self.num_topics = value.to_i
          when "init_alpha", "initial_alpha", "alpha"
            self.init_alpha = value.to_f
          when "est_alpha", "estimate_alpha"
            self.est_alpha = value.to_i
          when "verbose"
            self.verbose = value.to_i != 0
          end
        end

        true
      end

      def set_config(init_alpha, num_topics, max_iter, convergence, em_max_iter, em_convergence, est_alpha)
        self.init_alpha = init_alpha
        self.num_topics = num_topics
        self.max_iter = max_iter
        self.convergence = convergence
        self.em_max_iter = em_max_iter
        self.em_convergence = em_convergence
        self.est_alpha = est_alpha
        true
      end

      def em(_start)
        raise NotImplementedError, "#{self.class} must implement #em"
      end

      def beta
        raise NotImplementedError, "#{self.class} must implement #beta"
      end

      def gamma
        raise NotImplementedError, "#{self.class} must implement #gamma"
      end

      def compute_phi
        raise NotImplementedError, "#{self.class} must implement #compute_phi"
      end

      def model
        raise NotImplementedError, "#{self.class} must implement #model"
      end

      def topic_document_probability(_phi_matrix, _document_counts)
        nil
      end

      private

      def next_random_seed
        @random.rand(0..9_223_372_036_854_775_807)
      end

      def normalize!(weights)
        total = weights.sum.to_f

        if total <= 0.0
          uniform = 1.0 / weights.size
          weights.map! { uniform }
          return weights
        end

        weights.map! { |w| w / total }
      end

      def clone_matrix(matrix)
        Marshal.load(Marshal.dump(matrix))
      end
    end
  end
end
