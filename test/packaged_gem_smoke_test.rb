require_relative "test_helper"
require "tmpdir"
require "fileutils"
require_relative "../bin/packaged-gem-smoke"

class PackagedGemSmokeTest < Test::Unit::TestCase
  def test_gem_path_under_prefix_handles_symlinked_prefixes
    Dir.mktmpdir("packaged-smoke") do |tmpdir|
      real_root = File.join(tmpdir, "real")
      link_root = File.join(tmpdir, "link")
      gem_dir = File.join(real_root, "gems", "lda-ruby-0.4.0")

      FileUtils.mkdir_p(gem_dir)
      File.symlink(real_root, link_root)

      assert(
        Lda::PackagedGemSmoke.gem_path_under_prefix?(gem_dir, link_root),
        "expected symlinked prefix to match real gem path"
      )
      assert(
        Lda::PackagedGemSmoke.gem_path_under_prefix?(File.join(link_root, "gems", "lda-ruby-0.4.0"), real_root),
        "expected real prefix to match symlinked gem path"
      )
    end
  end

  def test_gem_path_under_prefix_rejects_neighbor_prefixes
    assert(
      !Lda::PackagedGemSmoke.gem_path_under_prefix?("/tmp/gemhome-other/gems/lda-ruby-0.4.0", "/tmp/gemhome"),
      "neighbor prefixes should not match"
    )
  end
end
