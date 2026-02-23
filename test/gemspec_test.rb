require_relative "test_helper"

class GemspecTest < Test::Unit::TestCase
  def test_gemspec_excludes_local_rust_build_artifacts
    spec = Gem::Specification.load(File.expand_path("../lda-ruby.gemspec", __dir__))
    assert_not_nil spec

    rust_target_files = spec.files.grep(%r{\Aext/lda-ruby-rust/target/})
    assert_equal [], rust_target_files
    assert(!spec.files.include?("ext/lda-ruby-rust/Cargo.lock"))
    assert(!spec.files.include?("ext/lda-ruby-rust/Makefile"))
  end

  def test_gemspec_declares_rust_extconf
    spec = Gem::Specification.load(File.expand_path("../lda-ruby.gemspec", __dir__))
    assert_not_nil spec

    assert(spec.extensions.include?("ext/lda-ruby-rust/extconf.rb"))
  end

  def test_gemspec_includes_release_runbook
    spec = Gem::Specification.load(File.expand_path("../lda-ruby.gemspec", __dir__))
    assert_not_nil spec

    assert(spec.files.include?("docs/release-runbook.md"))
  end
end
