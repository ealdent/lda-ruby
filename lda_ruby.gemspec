spec = Gem::Specification.new do |s| 
  s.name = "lda-ruby"
  s.version = "0.1.3"
  s.date = "2008-11-19"
  s.authors = ["Jason M. Adams", "David M. Blei"]
  s.email = "jasonmadams@gmail.com"
  s.homepage = "http://github.com/ealdent/lda-ruby"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby port of Latent Dirichlet Allocation by David M. Blei."
  s.extensions << "lib/extconf.rb"
  s.files = [ 
              "README",
              "license.txt",
              "lib/cokus.c", 
              "lib/cokus.h", 
              "lib/extconf.rb", 
              "lib/lda-alpha.c",
              "lib/lda-alpha.h",
              "lib/lda-data.c", 
              "lib/lda-data.h", 
              "lib/lda-inference.c", 
              "lib/lda-inference.h", 
              "lib/lda-model.c", 
              "lib/lda-model.h", 
              "lib/lda.h", 
              "lib/lda.rb", 
              "lib/utils.c", 
              "lib/utils.h"
            ]
  s.has_rdoc = true
end