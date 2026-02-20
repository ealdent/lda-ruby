# frozen_string_literal: true

require "mkmf"

extension_name = "lda-ruby/lda"
dir_config(extension_name)

$defs << "-DUSE_RUBY"
append_cflags("-Wall")
append_cflags("-Wextra")
append_cflags("-Wno-unused-parameter")

create_makefile(extension_name)
