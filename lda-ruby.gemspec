# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{lda-ruby}
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["David Blei", "Jason Adams"]
  s.date = %q{2009-07-24}
  s.description = %q{Ruby port of Latent Dirichlet Allocation by David M. Blei. See http://www.cs.princeton.edu/~blei/lda-c/.}
  s.email = %q{jasonmadams@gmail.com}
  s.extensions = ["ext/lda-ruby/extconf.rb"]
  s.extra_rdoc_files = [
    "README",
     "README.markdown"
  ]
  s.files = [
    ".gitignore",
     "README",
     "README.markdown",
     "Rakefile",
     "VERSION.yml",
     "ext/lda-ruby/Makefile",
     "ext/lda-ruby/cokus.c",
     "ext/lda-ruby/cokus.h",
     "ext/lda-ruby/extconf.rb",
     "ext/lda-ruby/lda-alpha.c",
     "ext/lda-ruby/lda-alpha.h",
     "ext/lda-ruby/lda-data.c",
     "ext/lda-ruby/lda-data.h",
     "ext/lda-ruby/lda-inference.c",
     "ext/lda-ruby/lda-inference.h",
     "ext/lda-ruby/lda-model.c",
     "ext/lda-ruby/lda-model.h",
     "ext/lda-ruby/lda.h",
     "ext/lda-ruby/utils.c",
     "ext/lda-ruby/utils.h",
     "lda-ruby.gemspec",
     "lib/lda-ruby.rb",
     "lib/lda-ruby/corpus/corpus.rb",
     "lib/lda-ruby/corpus/data_corpus.rb",
     "lib/lda-ruby/corpus/directory_corpus.rb",
     "lib/lda-ruby/corpus/text_corpus.rb",
     "lib/lda-ruby/document/data_document.rb",
     "lib/lda-ruby/document/document.rb",
     "lib/lda-ruby/document/text_document.rb",
     "lib/lda-ruby/vocabulary.rb",
     "license.txt",
     "test/data/.gitignore",
     "test/data/docs.dat",
     "test/data/wiki-test-docs.yml",
     "test/lda_ruby_test.rb",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://github.com/ealdent/lda-ruby}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib", "ext"]
  s.rubygems_version = %q{1.3.4}
  s.summary = %q{Ruby port of Latent Dirichlet Allocation by David M. Blei.}
  s.test_files = [
    "test/lda_ruby_test.rb",
     "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
