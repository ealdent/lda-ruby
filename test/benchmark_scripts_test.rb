# frozen_string_literal: true

require_relative "test_helper"
require "open3"

class BenchmarkScriptsTest < Test::Unit::TestCase
  def setup
    @repo_root = File.expand_path("..", __dir__)
    @check_rust_benchmark = File.join(@repo_root, "bin", "check-rust-benchmark")
  end

  def test_check_rust_benchmark_help
    stdout, stderr, status = Open3.capture3(@check_rust_benchmark, "--help", chdir: @repo_root)
    assert(status.success?, stderr)
    assert_match(/Usage: \.\/bin\/check-rust-benchmark/, stdout)
  end

  def test_check_rust_benchmark_rejects_unknown_argument
    _stdout, stderr, status = Open3.capture3(@check_rust_benchmark, "--unknown", chdir: @repo_root)
    assert(!status.success?, "expected check-rust-benchmark to fail for unknown args")
    assert_match(/Unknown argument/, stderr)
  end
end
