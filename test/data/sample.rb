#!/usr/bin/ruby

require 'rubygems'
require 'lda-ruby'

# Load the Corpus.  The AP data from David Blei's website is in the "DataCorpus" format
corpus = Lda::DataCorpus.new("ap/ap.dat")

# Initialize the Lda instance with the corpus
lda = Lda::Lda.new(corpus)

# Run the EM algorithm using random starting points.  Fixed starting points will use the first n documents
# to initialize the topics, where n is the number of topics.
lda.em("random")              # run EM algorithm using random starting points

# Load the vocabulary file necessary with DataCorpus objects
lda.load_vocabulary("ap/vocab.txt")

# Print the top 20 words per topic
lda.print_topics(20)
