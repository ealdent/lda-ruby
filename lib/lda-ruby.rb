# frozen_string_literal: true

require "lda-ruby/version"
require "rbconfig"

rust_extension_loaded = false
rust_dlext = RbConfig::CONFIG.fetch("DLEXT")

[
  "lda_ruby_rust",
  "../ext/lda-ruby-rust/target/release/lda_ruby_rust",
  "../ext/lda-ruby-rust/target/release/lda_ruby_rust.#{rust_dlext}",
  "../ext/lda-ruby-rust/target/debug/lda_ruby_rust",
  "../ext/lda-ruby-rust/target/debug/lda_ruby_rust.#{rust_dlext}"
].each do |rust_extension_candidate|
  begin
    if rust_extension_candidate.start_with?("../")
      require_relative rust_extension_candidate
    else
      require rust_extension_candidate
    end

    rust_extension_loaded = true
    break
  rescue LoadError
    next
  end
end

native_extension_loaded = false

begin
  require "lda-ruby/lda"
  native_extension_loaded = true
rescue LoadError
  begin
    require_relative "../ext/lda-ruby/lda"
    native_extension_loaded = true
  rescue LoadError
    native_extension_loaded = false
  end
end

LDA_RUBY_NATIVE_EXTENSION_LOADED = native_extension_loaded unless defined?(LDA_RUBY_NATIVE_EXTENSION_LOADED)
LDA_RUBY_RUST_EXTENSION_LOADED = rust_extension_loaded unless defined?(LDA_RUBY_RUST_EXTENSION_LOADED)

require "lda-ruby/document/document"
require "lda-ruby/document/data_document"
require "lda-ruby/document/text_document"
require "lda-ruby/corpus/corpus"
require "lda-ruby/corpus/data_corpus"
require "lda-ruby/corpus/text_corpus"
require "lda-ruby/corpus/directory_corpus"
require "lda-ruby/vocabulary"
require "lda-ruby/backends"

module Lda
  RUST_EXTENSION_LOADED = LDA_RUBY_RUST_EXTENSION_LOADED unless const_defined?(:RUST_EXTENSION_LOADED)
  NATIVE_EXTENSION_LOADED = LDA_RUBY_NATIVE_EXTENSION_LOADED unless const_defined?(:NATIVE_EXTENSION_LOADED)

  class Lda
    NATIVE_ALIAS_MAP = {
      fast_load_corpus_from_file: :__native_fast_load_corpus_from_file,
      "corpus=": :__native_set_corpus,
      em: :__native_em,
      load_settings: :__native_load_settings,
      set_config: :__native_set_config,
      max_iter: :__native_max_iter,
      "max_iter=": :__native_set_max_iter,
      convergence: :__native_convergence,
      "convergence=": :__native_set_convergence,
      em_max_iter: :__native_em_max_iter,
      "em_max_iter=": :__native_set_em_max_iter,
      em_convergence: :__native_em_convergence,
      "em_convergence=": :__native_set_em_convergence,
      init_alpha: :__native_init_alpha,
      "init_alpha=": :__native_set_init_alpha,
      est_alpha: :__native_est_alpha,
      "est_alpha=": :__native_set_est_alpha,
      num_topics: :__native_num_topics,
      "num_topics=": :__native_set_num_topics,
      verbose: :__native_verbose,
      "verbose=": :__native_set_verbose,
      beta: :__native_beta,
      gamma: :__native_gamma,
      compute_phi: :__native_compute_phi,
      model: :__native_model
    }.freeze

    NATIVE_ALIAS_MAP.each do |native_name, alias_name|
      next unless method_defined?(native_name)

      alias_method alias_name, native_name
      private alias_name
    end

    attr_reader :vocab, :corpus, :backend

    def initialize(corpus, backend: nil, random_seed: nil)
      @backend = Backends.build(host: self, requested: backend, random_seed: random_seed)

      load_default_settings

      @vocab = nil
      self.corpus = corpus
      @vocab = corpus.vocabulary.to_a if corpus.respond_to?(:vocabulary) && corpus.vocabulary

      @phi = nil
    end

    def backend_name
      @backend.name
    end

    def native_backend?
      backend_name == "native"
    end

    def rust_backend?
      backend_name == "rust"
    end

    def load_default_settings
      self.max_iter = 20
      self.convergence = 1e-6
      self.em_max_iter = 100
      self.em_convergence = 1e-4
      self.num_topics = 20
      self.init_alpha = 0.3
      self.est_alpha = 1

      [20, 1e-6, 100, 1e-4, 20, 0.3, 1]
    end

    def set_config(init_alpha, num_topics, max_iter, convergence, em_max_iter, em_convergence = self.em_convergence, est_alpha = self.est_alpha)
      @backend.set_config(
        Float(init_alpha),
        Integer(num_topics),
        Integer(max_iter),
        Float(convergence),
        Integer(em_max_iter),
        Float(em_convergence),
        Integer(est_alpha)
      )
    end

    def max_iter
      @backend.max_iter
    end

    def max_iter=(value)
      @backend.max_iter = Integer(value)
    end

    def convergence
      @backend.convergence
    end

    def convergence=(value)
      @backend.convergence = Float(value)
    end

    def em_max_iter
      @backend.em_max_iter
    end

    def em_max_iter=(value)
      @backend.em_max_iter = Integer(value)
    end

    def em_convergence
      @backend.em_convergence
    end

    def em_convergence=(value)
      @backend.em_convergence = Float(value)
    end

    def num_topics
      @backend.num_topics
    end

    def num_topics=(value)
      @backend.num_topics = Integer(value)
    end

    def init_alpha
      @backend.init_alpha
    end

    def init_alpha=(value)
      @backend.init_alpha = Float(value)
    end

    def est_alpha
      @backend.est_alpha
    end

    def est_alpha=(value)
      @backend.est_alpha = Integer(value)
    end

    def verbose
      @backend.verbose
    end

    def verbose=(value)
      @backend.verbose = !!value
    end

    def corpus=(corpus)
      @corpus = corpus
      @backend.corpus = corpus
      true
    end

    def load_corpus(filename)
      fast_load_corpus_from_file(filename)
    end

    def fast_load_corpus_from_file(filename)
      loaded = @backend.fast_load_corpus_from_file(filename)

      if @backend.corpus
        @corpus = @backend.corpus
        @vocab = @corpus.vocabulary.to_a if @corpus.respond_to?(:vocabulary) && @corpus.vocabulary
      elsif @corpus.nil?
        @corpus = DataCorpus.new(filename)
      end

      !!loaded
    end

    def load_settings(settings_file)
      @backend.load_settings(settings_file)
    end

    def load_vocabulary(vocab)
      if vocab.is_a?(Array)
        @vocab = Marshal.load(Marshal.dump(vocab)) # deep clone array
      elsif vocab.is_a?(Vocabulary)
        @vocab = vocab.to_a
      else
        @vocab = File.read(vocab).split(/\s+/)
      end

      true
    end

    def em(start = "random")
      @phi = nil
      @backend.em(start.to_s)
    end

    def beta
      @backend.beta
    end

    def gamma
      @backend.gamma
    end

    def model
      @backend.model
    end

    #
    # Visualization method for printing out the top +words_per_topic+ words
    # for each topic.
    #
    # See also +top_words+.
    #
    def print_topics(words_per_topic = 10)
      raise "No vocabulary loaded." unless @vocab

      beta.each_with_index do |topic, topic_num|
        indices = topic
          .each_with_index
          .sort_by { |score, _index| score }
          .reverse
          .first(words_per_topic)
          .map { |_score, index| index }

        puts "Topic #{topic_num}"
        puts "\t#{indices.map { |i| @vocab[i] }.join("\n\t")}"
        puts ""
      end

      nil
    end

    #
    # After the model has been run and a vocabulary has been loaded, return the
    # +words_per_topic+ top words chosen by the model for each topic.  This is
    # returned as a hash mapping the topic number to an array of top words
    # (in descending order of importance).
    #
    #   topic_number => [w1, w2, ..., w_n]
    #
    # See also +print_topics+.
    #
    def top_word_indices(words_per_topic = 10)
      raise "No vocabulary loaded." unless @vocab

      topics = {}

      beta.each_with_index do |topic, topic_num|
        topics[topic_num] = topic
          .each_with_index
          .sort_by { |score, _index| score }
          .reverse
          .first(words_per_topic)
          .map { |_score, index| index }
      end

      topics
    end

    def top_words(words_per_topic = 10)
      output = {}

      topics = top_word_indices(words_per_topic)
      topics.each_pair do |topic_num, words|
        output[topic_num] = words.map { |w| @vocab[w] }
      end

      output
    end

    #
    # Get the phi matrix which can be used to assign probabilities to words
    # belonging to a specific topic in each document.  The return value is a
    # 3D matrix:  num_docs x doc_length x num_topics.  The value is cached
    # after the first call, so if it needs to be recomputed, set the +recompute+
    # value to true.
    #
    def phi(recompute = false)
      @phi = compute_phi if @phi.nil? || recompute

      @phi
    end

    def compute_phi
      @backend.compute_phi
    end

    #
    # Compute the average log probability for each topic for each document in the corpus.
    # This method returns a matrix:  num_docs x num_topics with the average log probability
    # for the topic in the document.
    #
    def compute_topic_document_probability
      phi_matrix = phi
      document_counts = @corpus.documents.map(&:counts)

      backend_output = @backend.topic_document_probability(phi_matrix, document_counts)
      if valid_topic_document_probability_output?(backend_output, document_counts.size, num_topics)
        return backend_output
      end

      outp = []

      @corpus.documents.each_with_index do |doc, idx|
        tops = [0.0] * num_topics
        ttl = doc.counts.inject(0.0) { |sum, i| sum + i }

        phi_matrix[idx].each_with_index do |word_dist, word_idx|
          word_dist.each_with_index do |top_prob, top_idx|
            tops[top_idx] += Math.log([top_prob, 1e-300].max) * doc.counts[word_idx]
          end
        end

        tops = tops.map { |i| i / ttl }
        outp << tops
      end

      outp
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

    #
    # String representation displaying current settings.
    #
    def to_s
      outp = ["LDA Settings:"]
      outp << format("    Initial alpha: %0.6f", init_alpha)
      outp << format("      # of topics: %d", num_topics)
      outp << format("   Max iterations: %d", max_iter)
      outp << format("      Convergence: %0.6f", convergence)
      outp << format("EM max iterations: %d", em_max_iter)
      outp << format("   EM convergence: %0.6f", em_convergence)
      outp << format("   Estimate alpha: %d", est_alpha)
      outp << format("         Backend: %s", backend_name)

      outp.join("\n")
    end
  end
end
