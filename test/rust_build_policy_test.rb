require_relative "test_helper"
require "lda-ruby/rust_build_policy"

class RustBuildPolicyTest < Test::Unit::TestCase
  def test_default_policy_is_auto
    assert_equal "auto", Lda::RustBuildPolicy.resolve(nil)
    assert_equal "auto", Lda::RustBuildPolicy.resolve("")
    assert_equal "auto", Lda::RustBuildPolicy.resolve("  ")
  end

  def test_resolves_valid_values_case_insensitively
    assert_equal "always", Lda::RustBuildPolicy.resolve("always")
    assert_equal "always", Lda::RustBuildPolicy.resolve("ALWAYS")
    assert_equal "never", Lda::RustBuildPolicy.resolve("never")
    assert_equal "never", Lda::RustBuildPolicy.resolve("  NeVeR  ")
    assert_equal "auto", Lda::RustBuildPolicy.resolve("AUTO")
  end

  def test_invalid_policy_falls_back_to_auto
    assert_equal "auto", Lda::RustBuildPolicy.resolve("sometimes")
    assert_equal "auto", Lda::RustBuildPolicy.resolve("true")
  end
end
