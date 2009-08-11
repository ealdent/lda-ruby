$LOAD_PATH.unshift(File.dirname(__FILE__)) unless $LOAD_PATH.include?(File.dirname(__FILE__))

require 'lda-ruby/lda'
require 'lda-ruby/document/document'
require 'lda-ruby/document/data_document'
require 'lda-ruby/document/text_document'
require 'lda-ruby/corpus/corpus'
require 'lda-ruby/corpus/data_corpus'
require 'lda-ruby/corpus/text_corpus'
require 'lda-ruby/corpus/directory_corpus'
require 'lda-ruby/vocabulary'

module Lda
  class Lda
    attr_reader :vocab, :corpus

    def initialize(corpus)
      load_default_settings

      @vocab = nil
      self.corpus = corpus
      @vocab = corpus.vocabulary.to_a if corpus.vocabulary

      @phi = nil
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

    def load_corpus(filename)
      @corpus = Corpus.new
      @corpus.load_from_file(filename)

      true
    end

    def load_vocabulary(vocab)
      if vocab.is_a?(Array)
        @vocab = Marshal::load(Marshal::dump(vocab))      # deep clone array
      elsif vocab.is_a?(Vocabulary)
        @vocab = vocab.to_a
      else
        @vocab = File.open(vocab, 'r') { |f| f.read.split(/\s+/) }
      end

      true
    end

    #
    # Visualization method for printing out the top +words_per_topic+ words
    # for each topic.
    #
    # See also +top_words+.
    #
    def print_topics(words_per_topic = 10)
      raise 'No vocabulary loaded.' unless @vocab

      self.beta.each_with_index do |topic, topic_num|
        # Sort the topic array and return the sorted indices of the best scores
        indices = (topic.zip((0...@vocab.size).to_a).sort { |i, j| i[0] <=> j[0] }.map { |i, j| j }.reverse)[0...words_per_topic]

        puts "Topic #{topic_num}"
        puts "\t#{indices.map {|i| @vocab[i]}.join("\n\t")}"
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
      raise 'No vocabulary loaded.' unless @vocab

      # find the highest scoring words per topic
      topics = Hash.new
      indices = (0...@vocab.size).to_a

      self.beta.each_with_index do |topic, topic_num|
        topics[topic_num] = (topic.zip((0...@vocab.size).to_a).sort { |i, j| i[0] <=> j[0] }.map { |i, j| j }.reverse)[0...words_per_topic]
      end

      topics
    end

    def top_words(words_per_topic = 10)
      output = Hash.new

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
    def phi(recompute=false)
      if @phi.nil? || recompute
        @phi = self.compute_phi
      end

      @phi
    end

    #
    # Compute the average log probability for each topic for each document in the corpus.
    # This method returns a matrix:  num_docs x num_topics with the average log probability
    # for the topic in the document.
    #
    def compute_topic_document_probability
      outp = Array.new

      @corpus.documents.each_with_index do |doc, idx|
        tops = [0.0] * self.num_topics
        ttl  = doc.counts.inject(0.0) {|sum, i| sum + i}
        self.phi[idx].each_with_index do |word_dist, word_idx|
          word_dist.each_with_index do |top_prob, top_idx|
            tops[top_idx] += Math.log(top_prob) * doc.counts[word_idx]
          end
        end
        tops = tops.map {|i| i / ttl}
        outp << tops
      end

      outp
    end

    #
    # String representation displaying current settings.
    #
    def to_s
      outp = ["LDA Settings:"]
      outp << "    Initial alpha: %0.6f" % self.init_alpha
      outp << "      # of topics: %d" % self.num_topics
      outp << "   Max iterations: %d" % self.max_iter
      outp << "      Convergence: %0.6f" % self.convergence
      outp << "EM max iterations: %d" % self.em_max_iter
      outp << "   EM convergence: %0.6f" % self.em_convergence
      outp << "   Estimate alpha: %d" % self.est_alpha

      outp.join("\n")
    end
  end
end
