require 'rubygems'
require 'shoulda'
require 'yaml'
require 'lda-ruby'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

class Test::Unit::TestCase

  @filename = File.join(File.dirname(__FILE__), 'data', 'wiki-test-docs.yml')
  @filedocs = YAML::load_file(@filename)
  @corpus = Lda::TextCorpus.new(@filename)

  @lda = Lda::Lda.new(@corpus)

  @lda.verbose = false
  @lda.num_topics = 20
  @lda.em('random')
  @lda.print_topics(20)


end
