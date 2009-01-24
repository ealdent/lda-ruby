# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{lda-ruby}
  s.version = "0.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jason M. Adams", "David M. Blei"]
  s.date = %q{2009-01-24}
  s.email = %q{jasonmadams@gmail.com}
  s.extensions = ["lib/extconf.rb"]
  s.files = ["README", "license.txt", "lib/cokus.c", "lib/cokus.h", "lib/extconf.rb", "lib/lda-alpha.c", "lib/lda-alpha.h", "lib/lda-data.c", "lib/lda-data.h", "lib/lda-inference.c", "lib/lda-inference.h", "lib/lda-model.c", "lib/lda-model.h", "lib/lda.h", "lib/lda.rb", "lib/utils.c", "lib/utils.h"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/ealdent/lda-ruby}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Ruby port of Latent Dirichlet Allocation by David M. Blei.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
