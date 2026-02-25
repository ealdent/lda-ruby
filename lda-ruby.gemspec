# frozen_string_literal: true

require_relative "lib/lda-ruby/version"

variant = ENV.fetch("LDA_RUBY_GEM_VARIANT", "source")
valid_variants = %w[source precompiled].freeze
unless valid_variants.include?(variant)
  raise ArgumentError, "Unsupported LDA_RUBY_GEM_VARIANT=#{variant.inspect}. Expected one of: #{valid_variants.join(', ')}"
end

precompiled_variant = variant == "precompiled"

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
    "changelog_uri" => "#{spec.homepage}/blob/master/CHANGELOG.md",
    "lda_ruby_gem_variant" => variant
  }

  if precompiled_variant
    platform_override = ENV.fetch("LDA_RUBY_GEM_PLATFORM", "").strip
    platform_value = platform_override.empty? ? Gem::Platform.local.to_s : platform_override

    spec.platform = Gem::Platform.new(platform_value)
    spec.metadata["lda_ruby_platform"] = spec.platform.to_s
    spec.extensions = []
  else
    spec.extensions = ["ext/lda-ruby/extconf.rb", "ext/lda-ruby-rust/extconf.rb"]
  end

  spec.require_paths = ["lib"]

  included = %w[CHANGELOG.md Gemfile README.md VERSION.yml lda-ruby.gemspec license.txt]
  included += Dir.glob("docs/**/*")
  included += Dir.glob("ext/**/*")
  included += Dir.glob("lib/**/*")
  included += Dir.glob("test/**/*")
  allowed_precompiled_binary_patterns = [
    %r{\Alib/lda-ruby/lda\.(so|bundle|dylib|dll)\z},
    %r{\Alib/lda_ruby_rust\.(so|bundle|dylib|dll)\z}
  ]

  spec.files = included
    .reject { |path| File.directory?(path) }
    .reject { |path| path.start_with?("ext/lda-ruby-rust/target/") }
    .reject { |path| path == "ext/lda-ruby-rust/Cargo.lock" }
    .reject do |path|
      next false if precompiled_variant && allowed_precompiled_binary_patterns.any? { |pattern| pattern.match?(path) }

      path.end_with?(".o", ".so", ".bundle", ".dylib", ".dll", ".rlib", ".rmeta")
    end
    .reject do |path|
      ["Makefile", "ext/lda-ruby/Makefile", "ext/lda-ruby/mkmf.log", "ext/lda-ruby-rust/Makefile"].include?(path)
    end
    .uniq
    .sort

  if precompiled_variant
    missing_binaries = allowed_precompiled_binary_patterns.reject do |pattern|
      spec.files.any? { |path| pattern.match?(path) }
    end
    unless missing_binaries.empty?
      raise "Precompiled variant requires staged binaries under lib/: #{missing_binaries.map(&:source).join(', ')}"
    end
  end
end
