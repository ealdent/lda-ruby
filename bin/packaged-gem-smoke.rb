#!/usr/bin/env ruby
# frozen_string_literal: true

require "lda-ruby"

expected_backend = ENV.fetch("EXPECTED_BACKEND")
mode = ENV.fetch("SMOKE_MODE")
expected_gem_home_prefix = ENV["EXPECTED_GEM_HOME_PREFIX"]

if expected_gem_home_prefix
  spec = Gem.loaded_specs["lda-ruby"]
  unless spec&.full_gem_path&.start_with?(expected_gem_home_prefix)
    abort("Mode=#{mode}: expected installed gem under #{expected_gem_home_prefix.inspect}, got #{spec&.full_gem_path.inspect}")
  end
end

corpus = Lda::Corpus.new
corpus.add_document(Lda::TextDocument.new(corpus, "alpha beta gamma delta epsilon"))
corpus.add_document(Lda::TextDocument.new(corpus, "zeta eta theta iota kappa"))

lda = Lda::Lda.new(corpus)
unless lda.backend_name == expected_backend
  abort("Mode=#{mode}: expected backend #{expected_backend.inspect}, got #{lda.backend_name.inspect}")
end

lda.verbose = false
lda.num_topics = 2
lda.max_iter = 5
lda.em_max_iter = 8
lda.em("seeded")

topics = lda.top_words(3)
abort("Mode=#{mode}: expected 2 topics, got #{topics.size}") unless topics.size == 2
unless topics.values.all? { |words| words.is_a?(Array) && words.size == 3 }
  abort("Mode=#{mode}: expected 3 words per topic, got #{topics.inspect}")
end

tdp = lda.compute_topic_document_probability
abort("Mode=#{mode}: topic-document probability rows mismatch") unless tdp.is_a?(Array) && tdp.size == 2
unless tdp.all? { |row| row.is_a?(Array) && row.size == 2 && row.all? { |v| v.is_a?(Numeric) && v.finite? } }
  abort("Mode=#{mode}: invalid topic-document probability output #{tdp.inspect}")
end

puts("SMOKE mode=#{mode} backend=#{lda.backend_name} OK")
