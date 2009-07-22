require 'lib/lda-ruby'
require 'test/unit'
require 'yaml'

$vocab_set = YAML.load_file('vocab_set.yml')
$vocab_vec = YAML.load_file('vocab_vec.yml')
$docs      = YAML.load_file('docs.yml')

class LdaTest < Test::Unit::TestCase
  def test_corpus_01
    corpus = Lda::Corpus.new
    $docs.each {|tf| corpus.add_document(tf) }
    assert_equal $docs.size, corpus.num_docs
    assert_equal $docs.size, corpus.documents.size
    assert_equal $vocab_vec.size, corpus.num_terms
  end

  def test_document_01
    d = Lda::Document.new("5 1:2 3:1 4:2 7:3 12:1")
    assert_equal 5, d.length
    assert_equal 9, d.total # total terms/words
    assert_equal [1, 3, 4, 7, 12], d.words
    assert_equal [2, 1, 2, 3, 1], d.counts
    d2 = Lda::Document.new("170 219:2 256:2 389:1 257:1 292:2 143:1 181:14 107:1 1871:1 241:1 104:14 120:1 183:1 175:1 267:1 274:1 245:2 884:1 996:1 202:1 149:2 1264:1 182:1 275:1 2015:1 212:1 1292:1 367:1 142:1 221:2 1328:2 265:1 152:1 494:1 186:3 168:1 216:1 1184:1 284:2 276:1 151:1 164:1 290:1 249:1 150:1 141:1 125:2 1281:2 1953:1 196:1 112:3 281:1 314:1 934:2 286:2 134:1 148:6 225:1 114:2 211:1 147:1 300:1 303:1 266:1 201:1 191:1 124:8 244:1 209:1 170:2 517:1 105:1 248:1 7:1 155:2 675:1 246:1 571:1 224:1 285:1 289:1 119:3 230:4 262:1 2342:1 159:1 205:1 217:1 195:2 944:1 220:2 106:1 277:1 137:1 135:2 1458:1 118:9 2368:1 199:2 1798:1 242:1 239:2 127:3 264:3 2129:1 2076:1 103:1 154:2 238:1 102:5 108:1 197:1 268:1 184:2 19:2 255:1 430:1 173:1 309:1 138:2 261:1 272:1 5:2 128:3 1145:7 192:1 129:15 145:1 236:1 121:8 193:4 1356:1 140:1 840:3 171:2 172:2 721:1 935:1 160:2 185:1 207:1 1086:1 126:1 1132:1 130:5 157:1 271:2 100:4 132:1 200:1 188:6 204:1 109:5 153:1 158:1 304:1 208:1 146:3 110:2 218:1 2079:1 868:1 210:1 557:3 227:1 282:2 247:2 165:1 213:1 215:1")
    assert_equal 170, d2.length
    assert_equal 319, d2.total # total terms/words

    c = Lda::Corpus.new
    c.add_document(d)
    c.add_document(d2)
    assert_equal 174, c.num_terms

  end

  def test_lda_em_random
    corpus = Lda::Corpus.new
    $docs.each {|tf| corpus.add_document(tf) }
    corpus.instance_variable_set(:@num_terms, $vocab_vec.size)
    lda = Lda::Lda.new
    lda.corpus = corpus
    lda.em("random")
    lda.load_vocabulary($vocab_vec)
    puts lda.top_words
  end

  def test_lda_em_seed
#    corpus = Lda::Corpus.new
#    $docs.each {|tf| corpus.add_document(tf) }
#    lda = Lda::Lda.new
#    lda.corpus = corpus
#    lda.em("seeded")
  end

end
