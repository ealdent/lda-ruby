require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'yaml'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'lda-ruby'

class LdaRubyTest < Test::Unit::TestCase
  context "A Document instance" do
    setup do
      @corpus = Lda::Corpus.new
    end

    context "A typical Document" do
      setup do
        @document = Lda::Document.new(@corpus)
      end

      should "not have text" do
        assert !@document.has_text?
      end

      should "be empty" do
        assert_equal @document.total, 0
        assert_equal @document.length, 0
      end

      context "after adding words" do
        setup do
          @document.words << 1 << 2 << 3 << 4 << 5
          @document.counts << 2 << 1 << 1 << 1 << 3
          @document.recompute
        end

        should "have word count equal to what was added" do
          assert_equal @document.length, 5
        end

        should "have total words equal to the sum of the counts" do
          assert_equal @document.total, 8
        end
      end
    end

    context "A typical DataDocument" do
      setup do
        @data = '5 1:2 2:1 3:1 4:1 5:3'
        @document = Lda::DataDocument.new(@corpus, @data)
      end

      should "not have text" do
        assert !@document.has_text?
      end

      should "have word count equal to what was added" do
        assert_equal @document.length, 5
      end

      should "have total words equal to the sum of the counts" do
        assert_equal @document.total, 8
      end

      should "have words equal to the order they were entered" do
        assert_equal @document.words, [1, 2, 3, 4, 5]
      end

      should "have counts equal to the order they were entered" do
        assert_equal @document.counts, [2, 1, 1, 1, 3]
      end
    end

    context "A typical TextDocument" do
      setup do
        @text = 'stop words stop stop masterful stoppage buffalo buffalo buffalo'
        @document = Lda::TextDocument.new(@corpus, @text)
      end

      should "have text" do
        assert @document.has_text?
      end

      should "have word count equal to what was added" do
        assert_equal @document.length, 5
      end

      should "have total words equal to the sum of the counts" do
        assert_equal @document.total, @text.split(/ /).size
      end

      should "have tokens in the order they were entered" do
        assert_equal @document.tokens, @text.split(/ /)
      end
    end
  end

  context "A Corpus instance" do
    context "A typical Lda::Corpus instance" do
      setup do
        @corpus = Lda::Corpus.new
        @document1 = Lda::TextDocument.new(@corpus, 'This is the document that never ends.  Oh wait yeah it does.')
        @document2 = Lda::TextDocument.new(@corpus, 'A second document that is just as lame as the first.')
      end

      should "be able to add new documents" do
        assert @corpus.respond_to?(:add_document)
        @corpus.add_document(@document1)
        assert_equal @corpus.documents.size, 1
      end

      should "update vocabulary with words in the document" do
        @corpus.add_document(@document2)
        assert_equal @corpus.vocabulary.words.member?('lame'), true
      end
    end

    context "An Lda::DataCorpus instance loaded from a file" do
      setup do
        @filename = File.join(File.dirname(__FILE__), 'data', 'docs.dat')
        @filetext = File.open(@filename, 'r') { |f| f.read }
        @corpus = Lda::DataCorpus.new(@filename)
      end

      should "contain the number of documents equivalent to the number of lines in the file" do
        assert_equal @corpus.num_docs, @filetext.split(/\n/).size
      end

      should "not load any words into the vocabulary since none were given" do
        assert_equal @corpus.vocabulary.words.size, 0
      end
    end

    context "An Lda::TextCorpus instance loaded from a file" do
      setup do
        @filename = File.join(File.dirname(__FILE__), 'data', 'wiki-test-docs.yml')
        @filedocs = YAML::load_file(@filename)
        @corpus = Lda::TextCorpus.new(@filename)
      end

      should "contain the number of documents equivalent to the number of lines in the file" do
        assert_equal @corpus.num_docs, @filedocs.size
      end

      should "update the vocabulary with the words that were loaded" do
        assert @corpus.vocabulary.words.size > 0
      end
    end

    context "An Lda::DirectoryCorpus instance loaded from a directory" do
      setup do
        @path = File.join(File.dirname(__FILE__), 'data', 'tmp')
        @extension = 'txt'
        Dir.mkdir(@path)
        @original_filename = File.join(File.dirname(__FILE__), 'data', 'wiki-test-docs.yml')
        @filedocs = YAML::load_file(@original_filename)
        @filedocs.each_with_index do |doc, idx|
          File.open(File.join(@path, "doc_#{idx + 1}.txt"), 'w') { |f| f.write(doc) }
        end

        @corpus = Lda::DirectoryCorpus.new(@path, @extension)
      end

      should "load a document for every file in the directory" do
        assert_equal @corpus.num_docs, @filedocs.size
      end

      should "update the vocabulary with the words that were loaded" do
        assert @corpus.vocabulary.words.size > 0
      end

      teardown do
        Dir.glob(File.join(@path, "*.#{@extension}")).each { |f| File.unlink(f) }
        Dir.rmdir(@path)
      end
    end
  end

  context "A Vocabulary instance" do
    setup do
      @vocab = Lda::Vocabulary.new
      @words = ['word1', 'word2', 'word3', 'word4', 'word5', 'word6']
      @filename1 = File.join(File.dirname(__FILE__), 'data', 'tmp_file.txt')
      File.open(@filename1, 'w') do |f|
        @words.each { |w| f.write("#{w}\n") }
      end
      @filename2 = File.join(File.dirname(__FILE__), 'data', 'tmp_file.yml')
      File.open(@filename2, 'w') { |f| YAML::dump(@words, f) }
    end

    should "load a file containing a list of words, one per line" do
      assert @vocab.num_words == 0
      @vocab.load_file(@filename1)
      assert @vocab.words.size > 0
    end

    should "load a yaml file containing a list of words" do
      assert @vocab.num_words == 0
      @vocab.load_yaml(@filename2)
      assert @vocab.num_words > 0
    end

    should "return indexes for words in the order they were loaded" do
      @vocab.load_yaml(@filename2)
      @words.each_with_index do |word, idx|
        assert_equal @vocab.check_word(word), idx + 1
      end
    end

    teardown do
      File.unlink(@filename1)
      File.unlink(@filename2)
    end
  end

  context "An Lda::Lda instance" do
    setup do
      @filename = File.join(File.dirname(__FILE__), 'data', 'wiki-test-docs.yml')
      @filedocs = YAML::load_file(@filename)
      @corpus = Lda::TextCorpus.new(@filename)

      @lda = Lda::Lda.new(@corpus)
    end

    should "have loaded the vocabulary from the corpus" do
      assert !@lda.vocab.nil?
    end

    should "have loaded the same number of words in the vocabulary as are in the original" do
      assert_equal @lda.vocab.size, @corpus.vocabulary.num_words
    end

    should "have default values for the main settings" do
      assert !@lda.max_iter.nil?
      assert !@lda.convergence.nil?
      assert !@lda.em_max_iter.nil?
      assert !@lda.em_convergence.nil?
      assert !@lda.num_topics.nil?
      assert !@lda.init_alpha.nil?
      assert !@lda.est_alpha.nil?
    end

    context "after running em" do
      setup do
        @lda.verbose = false
        @lda.num_topics = 8
        @lda.em('random')
      end

      should "phi should be defined" do
        assert !@lda.phi.nil?
      end

      should "return the top 10 list of words for each topic" do
        topics = @lda.top_words(10)
        assert topics.is_a?(Hash)
        assert_equal topics.size, @lda.num_topics

        topics.each_pair do |topic, top_n_words|
          assert_equal top_n_words.size, 10
        end
      end

      context "after computing topic-document probabilities" do
        setup do
          @topic_doc_probs = @lda.compute_topic_document_probability
        end

        should "have a row for each document" do
          assert_equal @topic_doc_probs.size, @corpus.num_docs
        end

        should "have columns for each topic" do
          @topic_doc_probs.each do |doc|
            assert_equal doc.size, @lda.num_topics
          end
        end
      end
    end
  end
end
