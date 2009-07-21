$LOAD_PATH.unshift(File.dirname(__FILE__)) unless $LOAD_PATH.include?(File.dirname(__FILE__))

require 'lda-ruby/base_document'
require 'lda-ruby/document'
require 'lda-ruby/text_document'
require 'lda-ruby/corpus'
require 'lda-ruby/lda'
require 'set'

module Lda
  class Lda
    attr_reader :vocab, :corpus

    #
    # Create a new LDA instance with the default settings.
    #
    def initialize
      self.load_default_settings
      @corpus = nil
      @vocab = nil
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
      nil
    end

    #
    # Load the corpus from file.  The corpus is in svmlight-style where the
    # first element of each line is the number of words in the document and
    # then each element is the pair word_idx:weight.
    #
    #   num_words word1:wgt1 word2:wgt2 ... word_n:wgt_n
    #
    # The value for the number of words should equal the number of pairs
    # following it, though this isn't strictly enforced in this method.
    #
    def load_corpus(filename)
      @corpus = Corpus.new
      @corpus.load_from_file(filename)

      true
    end

    #
    # Load the vocabulary file which is a list of words, one per line
    # where the line number corresponds the word list index.  This allows
    # the words to be extracted for topics later.
    #
    # +vocab+ can either be the filename of the vocabulary file or the
    # array itself.
    #
    def load_vocabulary(vocab)
      if vocab.is_a?(Array)
        @vocab = Marshal::load(Marshal::dump(vocab))      # deep clone array
      else
        @vocab = File.open(vocab, 'r') { |f| f.read.split(/[\n\r]+/) }
      end

      true
    end


    #
    # Visualization method for printing out the top +words_per_topic+ words
    # for each topic.
    #
    # See also +top_words+.
    #
    def print_topics(words_per_topic=10)
      unless @vocab
        puts "No vocabulary loaded."
        return nil
      end

      beta = self.beta
      indices = (0..(@vocab.size - 1)).to_a
      topic_num = 0
      beta.each do |topic|
        indices.sort! {|x, y| -(topic[x] <=> topic[y])}
        outp = []
        puts "Topic #{topic_num}"
        words_per_topic.times do |i|
          outp << @vocab[indices[i]]
        end
        puts "\t" + outp.join("\n\t")
        puts ""
        topic_num += 1
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
    def top_words(words_per_topic=10)
      unless @vocab
        puts "No vocabulary loaded."
        return nil
      end

      # find the highest scoring words per topic
      topics = Hash.new
      indices = (0...@vocab.size).to_a

      begin
        beta.each_with_index do |topic, topic_idx|
          indices.sort! {|x, y| -(topic[x] <=> topic[y])}
          topics[topic_idx] = indices.first(words_per_topic).map { |i| @vocab[i] }
        end
      rescue NoMethodError
        puts "Error:  model has not been run."
        topics = nil
      end

      topics
    end


    #
    # Get the phi matrix which can be used to assign probabilities to words
    # belonging to a specific topic in each document.  The return value is a
    # 3D matrix:  num_docs x doc_length x num_topics.  The value is cached
    # after the first call, so if it needs to be recomputed, set the +recompute+
    # value to true.
    #
    def phi(recompute=false)
      if not @phi or recompute
        # either the phi variable has not been instantiated or the recompute flag has been set
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
      outp = []
      outp << "LDA Settings:"
      outp << "    Initial alpha: %0.6f" % self.init_alpha
    	outp << "      # of topics: %d" % self.num_topics
    	outp << "   Max iterations: %d" % self.max_iter
    	outp << "      Convergence: %0.6f" % self.convergence
    	outp << "EM max iterations: %d" % self.em_max_iter
    	outp << "   EM convergence: %0.6f" % self.em_convergence
    	outp << "   Estimate alpha: %d" % self.est_alpha

    	return outp.join("\n")
    end
  end
end
