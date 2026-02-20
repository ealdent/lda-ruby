# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/clean"
require "rake/testtask"
require "rbconfig"

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
    sh cargo, "build", "--release"
  end
end

desc "Run unit tests"
Rake::TestTask.new(:test) do |test|
  test.libs << "lib" << "test"
  test.pattern = "test/**/*_test.rb"
  test.warning = true
end

task test: :compile
task default: :test
