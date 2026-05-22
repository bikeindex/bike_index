# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is used only by review apps (and any future Kamal-based deploys).
# Production runs on Cloud66 — not from this file.

ARG RUBY_VERSION=4.0.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Base runtime packages.
# - libpq5 / postgresql-client: pg gem + bin/docker-entrypoint psql calls
# - libvips: ruby-vips
# - imagemagick: mini_magick
# - libjemalloc2: memory savings under load
# - curl: health checks
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      imagemagick \
      libjemalloc2 \
      libvips \
      libyaml-0-2 \
      postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Build stage
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libvips-dev \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompile assets. Bike Index doesn't use RAILS_MASTER_KEY (no credentials.yml.enc),
# so a dummy SECRET_KEY_BASE is enough. REDIS_URL is set because some initializers
# touch the Redis config at boot.
RUN SECRET_KEY_BASE=dummy REDIS_URL="redis://localhost:6379" ./bin/rails assets:precompile

# Final stage
FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
