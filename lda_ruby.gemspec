Gem::Specification.new do |s| 
  s.name = "lda-ruby"
  s.version = "0.1.2"
  s.date = "2008-11-14"
  s.authors = ["Jason M. Adams", "David M. Blei"]
  s.email = "jasonmadams@gmail.com"
  s.homepage = "http://github.com/ealdent/lda-ruby"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby port of Latent Dirichlet Allocation by David M. Blei."
  #s.files = FileList["./*"].to_a
  s.files = [ 
              "README",
              "license.txt",
              "cokus.c", 
              "cokus.h", 
              "extconf.rb", 
              "lda-alpha.c", 
              "lda-alpha.h", 
              "lda-data.c", 
              "lda-data.h", 
              "lda-inference.c", 
              "lda-inference.h", 
              "lda-model.c", 
              "lda-model.h", 
              "lda.h", 
              "lda.rb", 
              "utils.c", 
              "utils.h"]
  #s.require_path = "."
  s.has_rdoc = true
end
