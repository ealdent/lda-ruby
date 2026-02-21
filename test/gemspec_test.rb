require_relative "test_helper"

class GemspecTest < Test::Unit::TestCase
  def test_gemspec_excludes_local_rust_build_artifacts
    spec = Gem::Specification.load(File.expand_path("../lda-ruby.gemspec", __dir__))
    assert_not_nil spec

    rust_target_files = spec.files.grep(%r{\Aext/lda-ruby-rust/target/})
    assert_equal [], rust_target_files
    assert(!spec.files.include?("ext/lda-ruby-rust/Cargo.lock"))
  end
end
