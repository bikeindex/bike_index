# syntax=docker/dockerfile:1
# Multi-stage Dockerfile for Bike Index review apps.
# Not currently used by production (Cloud66) — only by Kamal-based review apps.

ARG RUBY_VERSION=4.0.2
ARG NODE_VERSION=24.15.0

#############
# Base image — runtime deps only
#############
FROM ruby:${RUBY_VERSION}-slim AS base

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1 \
    LANG=C.UTF-8

WORKDIR /rails

# Runtime libraries: libpq for pg, libvips for ruby-vips, imagemagick for mini_magick,
# jemalloc for memory, curl for health checks, tzdata for timezones, ca-certs for TLS.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      imagemagick \
      libjemalloc2 \
      libpq5 \
      libvips42 \
      libyaml-0-2 \
      postgresql-client \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2 \
    MALLOC_CONF=dirty_decay_ms:1000,narenas:2,background_thread:true

#############
# Build stage — compile gems and assets
#############
FROM base AS build

ARG NODE_VERSION

# Build deps: compilers, headers for native gems, git for github-sourced gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libvips-dev \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Node — needed for asset:precompile (tailwind, importmap)
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install gems first (cacheable layer)
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3 && \
    bundle exec bootsnap precompile --gemfile && \
    rm -rf /usr/local/bundle/cache /usr/local/bundle/ruby/*/cache

# Install Node deps (lockfile-driven if package-lock.json is present)
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund

# Copy the rest of the app
COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# Precompile assets (sprockets + dartsass + tailwind + importmap).
# SECRET_KEY_BASE must be present at precompile time but is irrelevant for assets;
# a dummy value is fine.
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

#############
# Runtime stage — slim final image
#############
FROM base AS runtime

# Non-root user (mirrors Rails 8 generated Dockerfile convention)
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

COPY --from=build --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails

USER rails

EXPOSE 3000

# Default to web; the worker role overrides this in config/deploy.review.yml
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "-b", "tcp://0.0.0.0:3000"]
