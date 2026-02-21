# frozen_string_literal: true

require_relative "lib/lda-ruby/version"

Gem::Specification.new do |spec|
  spec.name = "lda-ruby"
  spec.version = Lda::VERSION
  spec.authors = ["David Blei", "Jason Adams", "Rio Akasaka"]
  spec.email = ["jasonmadams@gmail.com"]

  spec.summary = "Ruby implementation of Latent Dirichlet Allocation (LDA)."
  spec.description = "Ruby wrapper and toolkit for Latent Dirichlet Allocation based on the original lda-c implementation by David M. Blei."
  spec.homepage = "https://github.com/ealdent/lda-ruby"
  spec.license = "GPL-2.0-or-later"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/master/CHANGELOG.md"
  }

  spec.extensions = ["ext/lda-ruby/extconf.rb"]
  spec.require_paths = ["lib"]

  included = %w[CHANGELOG.md Gemfile README.md VERSION.yml lda-ruby.gemspec license.txt]
  included += Dir.glob("docs/**/*")
  included += Dir.glob("ext/**/*")
  included += Dir.glob("lib/**/*")
  included += Dir.glob("test/**/*")

  spec.files = included
    .reject { |path| File.directory?(path) }
    .reject { |path| path.start_with?("ext/lda-ruby-rust/target/") }
    .reject { |path| path == "ext/lda-ruby-rust/Cargo.lock" }
    .reject { |path| path.end_with?(".o", ".so", ".bundle", ".dylib", ".dll", ".rlib", ".rmeta") }
    .reject { |path| ["Makefile", "ext/lda-ruby/Makefile", "ext/lda-ruby/mkmf.log"].include?(path) }
    .uniq
    .sort
end
