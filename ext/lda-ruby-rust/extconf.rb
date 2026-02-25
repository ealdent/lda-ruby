# frozen_string_literal: true

require "fileutils"
require "rbconfig"

require_relative "../../lib/lda-ruby/rust_build_policy"

module Lda
  module RustExtensionBuild
    module_function

    def run
      policy = RustBuildPolicy.resolve
      puts("Rust extension build policy: #{policy} (#{RustBuildPolicy::ENV_KEY})")

      case policy
      when RustBuildPolicy::NEVER
        puts("Skipping Rust extension build (policy=#{RustBuildPolicy::NEVER}).")
      when RustBuildPolicy::ALWAYS
        ensure_cargo_available!
        build_and_stage!
      else
        if cargo_available?
          build_and_stage!
        else
          puts("cargo not found; skipping Rust extension build (policy=#{RustBuildPolicy::AUTO}).")
        end
      end

      write_noop_makefile
    rescue StandardError => e
      if policy == RustBuildPolicy::ALWAYS
        abort("Rust extension build failed with #{RustBuildPolicy::ENV_KEY}=#{RustBuildPolicy::ALWAYS}: #{e.message}")
      end

      warn("Rust extension build skipped after error in auto mode: #{e.message}")
      write_noop_makefile
    end

    def ensure_cargo_available!
      return if cargo_available?

      abort("cargo not found in PATH but #{RustBuildPolicy::ENV_KEY}=#{RustBuildPolicy::ALWAYS} was requested.")
    end

    def cargo_available?
      cargo = ENV.fetch("CARGO", "cargo")
      system(cargo, "--version", out: File::NULL, err: File::NULL)
    end

    def build_and_stage!
      cargo = ENV.fetch("CARGO", "cargo")
      Dir.chdir(__dir__) do
        env = rust_build_env
        success =
          if env.empty?
            system(cargo, "build", "--release")
          else
            system(env, cargo, "build", "--release")
          end
        success or raise "cargo build --release failed"
      end

      source = File.join(__dir__, "target", "release", rust_cdylib_filename)
      raise "Rust extension artifact not found at #{source}" unless File.exist?(source)

      destination = File.expand_path("../../lib/lda_ruby_rust.#{RbConfig::CONFIG.fetch('DLEXT')}", __dir__)
      FileUtils.cp(source, destination)
      puts("Staged Rust extension to #{destination}")
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

    def write_noop_makefile
      File.write(
        File.join(__dir__, "Makefile"),
        <<~MAKEFILE
          all:
          \t@echo "Rust extension handled by extconf.rb"

          install:
          \t@echo "Rust extension handled by extconf.rb"

          clean:
          \t@true

          distclean: clean
        MAKEFILE
      )
    end
  end
end

Lda::RustExtensionBuild.run
