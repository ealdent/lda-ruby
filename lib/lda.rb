require 'set'

module Lda
  
  #
  # Corpus class handles the data passed to the LDA algorithm.
  #
  class Corpus
    attr_reader :documents, :num_docs, :num_terms

    #
    # Create a blank corpus object.  Either add documents to it
    # using the +add_document+ method or load the data from a file
    # using +load_from_file+.
    #
    def initialize(filename=nil)
      @documents = Array.new
      @all_terms = Set.new
      @num_terms = 0
      @num_docs  = 0
      
      if filename
        self.load_from_file(filename)
      end
    end
    
    # Add a new document to the corpus.  This can either be
    # an svmlight-style formatted line with the first element
    # being the number of words, or it can be a Document object.
    def add_document(doc)
      if doc.is_a?(Document)
        @documents << doc
        @all_terms = @all_terms + doc.words
      elsif doc.is_a?(String)
        d = Document.new(doc)
        @all_terms = @all_terms + d.words
        @documents << d
      end
      @num_docs += 1
      @num_terms = @all_terms.size
      true
    end
    
    # Populate this corpus from the data in the file.
    def load_from_file(filename)
      File.open(filename, 'r') do |f|
        f.each do |line|
          self.add_document(line)
        end
      end
      true
    end
  end

  # 
  # A single document.
  #
  class Document
    attr_accessor :words, :counts
    attr_reader :length, :total
    
    # Create the Document using the svmlight-style text line:
    # 
    #   num_words w1:freq1 w2:freq2 ... w_n:freq_n
    # 
    # Ex.
    #   5 1:2 3:1 4:2 7:3 12:1
    #
    # The value for the number of words should equal the number of pairs
    # following it, though this isn't strictly enforced.  Order of word-pair
    # indices is not important.
    # 
    def initialize(doc_line=nil)
      if doc_line.is_a?(String)
        tmp = doc_line.split
        @words = Array.new
        @counts = Array.new
        @total = 0
        tmp.slice(1,tmp.size).each do |pair|
          tmp2 = pair.split(":")
          @words << tmp2[0].to_i
          @counts << tmp2[1].to_i
        end
        @length = @words.size
        @total = @counts.inject(0) {|sum, i| sum + i}
      else    # doc_line == nil
        @words = Array.new
        @counts = Array.new
        @total = 0
        @length = 0
      end
    end
    
    
    #
    # Recompute the total and length values if the document has been
    # altered externally.  This probably won't happen, but might be useful
    # if you want to subclass +Document+.
    #
    def recompute
      @total = @counts.inject(0) {|sum, i| sum + i}
      @length = @words.size
    end
  end
  
  
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
    
    # 
    # Load the default settings.
    #  * max_iter = 20
    #  * convergence = 1e-6
    #  * em_max_iter = 100
    #  * em_convergence = 1e-4
    #  * num_topics = 20
    #  * init_alpha = 0.3
    #  * est_alpha = 1
    # 
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
      c = Corpus.new
      c.load_from_file(filename)
      self.corpus = c
      @corpus = c
      
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
      @vocab = Array.new
      
      File.open(filename, 'r') do |f|
        f.each do |line|
          @vocab << line.strip
        end
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
      
      # Load the model
      beta = self.beta
      unless beta
        puts "Model has not been run."
        return nil
      end
      
      # find the highest scoring words per topic
      topics = Hash.new
      indices = (0..(@vocab.size - 1)).to_a
      topic_num = 0
      beta.each do |topic|
        topics[topic_num] = Array.new
        indices.sort! {|x, y| -(topic[x] <=> topic[y])}
        words_per_topic.times do |i|
          topics[topic_num] << @vocab[indices[i]]
        end
        topic_num += 1
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

# load the c-side stuff
require 'lda_ext'