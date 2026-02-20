# syntax=docker/dockerfile:1.7

FROM ruby:3.3-bookworm

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY Gemfile lda-ruby.gemspec README.md CHANGELOG.md VERSION.yml ./
COPY lib ./lib

RUN bundle install

COPY . .

CMD ["bash"]
