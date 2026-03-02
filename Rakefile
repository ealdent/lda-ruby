# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/clean"
require "rake/testtask"
require "rbconfig"
require "fileutils"

EXT_DIR = File.expand_path("ext/lda-ruby", __dir__)
EXT_MAKEFILE = File.join(EXT_DIR, "Makefile")
EXT_SHARED_OBJECT = File.join(EXT_DIR, "lda.#{RbConfig::CONFIG.fetch("DLEXT")}")
RUST_EXT_DIR = File.expand_path("ext/lda-ruby-rust", __dir__)
RUST_TARGET_DIR = File.join(RUST_EXT_DIR, "target")

CLEAN.include(File.join(EXT_DIR, "*.o"))
CLOBBER.include(EXT_MAKEFILE, File.join(EXT_DIR, "mkmf.log"), EXT_SHARED_OBJECT)
CLOBBER.include(RUST_TARGET_DIR)

desc "Build native extension"
task :compile do
  Dir.chdir(EXT_DIR) do
    sh RbConfig.ruby, "extconf.rb"
    sh "make"
  end
end

desc "Build experimental Rust extension (requires cargo)"
task :compile_rust do
  cargo = ENV.fetch("CARGO", "cargo")
  unless system(cargo, "--version", out: File::NULL, err: File::NULL)
    abort "cargo not found in PATH. Install Rust toolchain or skip compile_rust."
  end

  Dir.chdir(RUST_EXT_DIR) do
    sh rust_build_env, cargo, "build", "--release"
  end

  staged_path = stage_rust_extension_for_ruby
  puts "Staged Rust extension at #{staged_path}"
end

desc "Run unit tests"
Rake::TestTask.new(:test) do |test|
  test.libs << "lib" << "test"
  test.pattern = "test/**/*_test.rb"
  test.warning = true
end

task test: :compile
task default: :test

def stage_rust_extension_for_ruby
  source = rust_cdylib_source
  unless source
    abort(
      "Expected Rust extension artifact at one of: " \
      "#{rust_cdylib_candidates.join(', ')}, but none were produced."
    )
  end

  destination = File.join(
    RUST_EXT_DIR,
    "target",
    "release",
    "lda_ruby_rust.#{RbConfig::CONFIG.fetch("DLEXT")}"
  )
  FileUtils.cp(source, destination)
  destination
end

def rust_cdylib_source
  rust_cdylib_candidates.find { |path| File.exist?(path) }
end

def rust_cdylib_candidates
  rust_cdylib_filenames.map { |filename| File.join(RUST_EXT_DIR, "target", "release", filename) }
end

def rust_cdylib_filenames
  host_os = RbConfig::CONFIG.fetch("host_os")
  case host_os
  when /mswin|mingw|cygwin/
    # On Windows cargo may emit either prefixed or unprefixed DLL names.
    ["lda_ruby_rust.dll", "liblda_ruby_rust.dll"]
  else
    extension =
      case host_os
      when /darwin/
        "dylib"
      else
        "so"
      end

    ["liblda_ruby_rust.#{extension}"]
  end
end

def rust_cdylib_filename
  rust_cdylib_filenames.first
end

def rust_build_env
  host_os = RbConfig::CONFIG.fetch("host_os")
  return {} unless host_os.match?(/darwin/)

  dynamic_lookup_flag = "-C link-arg=-Wl,-undefined,dynamic_lookup"
  existing = ENV.fetch("RUSTFLAGS", "")
  merged =
    case host_os
    when /darwin/
      if existing.include?(dynamic_lookup_flag)
        existing
      else
        [existing, dynamic_lookup_flag].reject(&:empty?).join(" ")
      end
    else
      existing
    end

  { "RUSTFLAGS" => merged }
end
