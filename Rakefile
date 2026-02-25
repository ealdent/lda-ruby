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
  unless system("command -v #{cargo} >/dev/null 2>&1")
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
  source = File.join(RUST_EXT_DIR, "target", "release", rust_cdylib_filename)
  unless File.exist?(source)
    abort "Expected Rust extension artifact at #{source}, but it was not produced."
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

def rust_cdylib_filename
  host_os = RbConfig::CONFIG.fetch("host_os")
  extension =
    case host_os
    when /darwin/
      "dylib"
    when /mswin|mingw|cygwin/
      "dll"
    else
      "so"
    end

  "liblda_ruby_rust.#{extension}"
end

def rust_build_env
  host_os = RbConfig::CONFIG.fetch("host_os")
  return {} unless host_os.match?(/darwin/)

  dynamic_lookup_flag = "-C link-arg=-Wl,-undefined,dynamic_lookup"
  existing = ENV.fetch("RUSTFLAGS", "")
  merged =
    if existing.include?(dynamic_lookup_flag)
      existing
    else
      [existing, dynamic_lookup_flag].reject(&:empty?).join(" ")
    end

  { "RUSTFLAGS" => merged }
end
