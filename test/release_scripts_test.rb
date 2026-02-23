require_relative "test_helper"
require "open3"

class ReleaseScriptsTest < Test::Unit::TestCase
  def setup
    @repo_root = File.expand_path("..", __dir__)
    @check_version_sync = File.join(@repo_root, "bin", "check-version-sync")
    @release_prepare = File.join(@repo_root, "bin", "release-prepare")
  end

  def test_check_version_sync_passes_for_repository_versions
    stdout, stderr, status = Open3.capture3(@check_version_sync, chdir: @repo_root)
    assert(status.success?, "stdout=#{stdout}\nstderr=#{stderr}")
    assert_match(/Version sync OK:/, stdout)
  end

  def test_check_version_sync_fails_for_mismatched_tag
    _stdout, stderr, status = Open3.capture3(@check_version_sync, "--tag", "v9.9.9", chdir: @repo_root)
    assert(!status.success?, "expected check-version-sync to fail for mismatched tag")
    assert_match(/does not match expected tag/, stderr)
  end

  def test_check_version_sync_print_tag_matches_library_version
    stdout, stderr, status = Open3.capture3(@check_version_sync, "--print-tag", chdir: @repo_root)
    assert(status.success?, "stdout=#{stdout}\nstderr=#{stderr}")
    assert_equal("v#{Lda::VERSION}", stdout.strip)
  end

  def test_release_prepare_dry_run_does_not_change_files
    version_rb_path = File.join(@repo_root, "lib", "lda-ruby", "version.rb")
    version_yml_path = File.join(@repo_root, "VERSION.yml")
    changelog_path = File.join(@repo_root, "CHANGELOG.md")

    baseline = {
      version_rb_path => File.read(version_rb_path),
      version_yml_path => File.read(version_yml_path),
      changelog_path => File.read(changelog_path)
    }

    stdout, stderr, status = Open3.capture3(
      @release_prepare,
      "9.9.9",
      "--allow-dirty",
      "--dry-run",
      chdir: @repo_root
    )
    assert(status.success?, "stdout=#{stdout}\nstderr=#{stderr}")
    assert_match(/Dry run: would update/, stdout)

    baseline.each do |path, original|
      assert_equal(original, File.read(path), "#{path} changed during dry-run")
    end
  end
end
