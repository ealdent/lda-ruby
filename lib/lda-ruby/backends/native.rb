# frozen_string_literal: true

module Lda
  module Backends
    class Native < Base
      REQUIRED_NATIVE_METHODS = %i[
        __native_fast_load_corpus_from_file
        __native_load_settings
        __native_set_config
        __native_em
        __native_beta
        __native_gamma
        __native_compute_phi
        __native_model
        __native_set_corpus
        __native_max_iter
        __native_set_max_iter
        __native_convergence
        __native_set_convergence
        __native_em_max_iter
        __native_set_em_max_iter
        __native_em_convergence
        __native_set_em_convergence
        __native_init_alpha
        __native_set_init_alpha
        __native_num_topics
        __native_set_num_topics
        __native_est_alpha
        __native_set_est_alpha
        __native_verbose
        __native_set_verbose
      ].freeze

      def self.available?(host)
        REQUIRED_NATIVE_METHODS.all? { |method_name| host.respond_to?(method_name, true) }
      end

      def initialize(host, random_seed: nil)
        super(random_seed: random_seed)
        @host = host
      end

      def name
        "native"
      end

      def corpus=(corpus)
        @corpus = corpus
        @host.__send__(:__native_set_corpus, corpus)
      end

      def fast_load_corpus_from_file(filename)
        @host.__send__(:__native_fast_load_corpus_from_file, filename)
      end

      def load_settings(settings_file)
        @host.__send__(:__native_load_settings, settings_file)
      end

      def set_config(init_alpha, num_topics, max_iter, convergence, em_max_iter, em_convergence, est_alpha)
        @host.__send__(
          :__native_set_config,
          init_alpha,
          num_topics,
          max_iter,
          convergence,
          em_max_iter,
          em_convergence,
          est_alpha
        )
      end

      def max_iter
        @host.__send__(:__native_max_iter)
      end

      def max_iter=(value)
        @host.__send__(:__native_set_max_iter, Integer(value))
      end

      def convergence
        @host.__send__(:__native_convergence)
      end

      def convergence=(value)
        @host.__send__(:__native_set_convergence, Float(value))
      end

      def em_max_iter
        @host.__send__(:__native_em_max_iter)
      end

      def em_max_iter=(value)
        @host.__send__(:__native_set_em_max_iter, Integer(value))
      end

      def em_convergence
        @host.__send__(:__native_em_convergence)
      end

      def em_convergence=(value)
        @host.__send__(:__native_set_em_convergence, Float(value))
      end

      def init_alpha
        @host.__send__(:__native_init_alpha)
      end

      def init_alpha=(value)
        @host.__send__(:__native_set_init_alpha, Float(value))
      end

      def num_topics
        @host.__send__(:__native_num_topics)
      end

      def num_topics=(value)
        @host.__send__(:__native_set_num_topics, Integer(value))
      end

      def est_alpha
        @host.__send__(:__native_est_alpha)
      end

      def est_alpha=(value)
        @host.__send__(:__native_set_est_alpha, Integer(value))
      end

      def verbose
        @host.__send__(:__native_verbose)
      end

      def verbose=(value)
        @host.__send__(:__native_set_verbose, !!value)
      end

      def em(start)
        @host.__send__(:__native_em, start)
      end

      def beta
        @host.__send__(:__native_beta)
      end

      def gamma
        @host.__send__(:__native_gamma)
      end

      def compute_phi
        @host.__send__(:__native_compute_phi)
      end

      def model
        @host.__send__(:__native_model)
      end
    end
  end
end
