# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{lda-ruby}
  s.version = "0.2.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jason M. Adams", "David M. Blei"]
  s.date = %q{2009-07-19}
  s.email = %q{jasonmadams@gmail.com}
  s.extensions = ["lib/extconf.rb"]
  s.extra_rdoc_files = [
    "README",
     "README.markdown"
  ]
  s.files = [
    "README",
     "VERSION.yml",
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
     "lib/utils.h",
     "license.txt"
  ]
  s.homepage = %q{http://github.com/ealdent/lda-ruby}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.4}
  s.summary = %q{Ruby port of Latent Dirichlet Allocation by David M. Blei.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<stemmer>, [">= 0"])
    else
      s.add_dependency(%q<stemmer>, [">= 0"])
    end
  else
    s.add_dependency(%q<stemmer>, [">= 0"])
  end
end
