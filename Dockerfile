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
# - cron: the `cron` server role in config/deploy.review.yml
# - ripgrep: the read_logged_searches rake task (rg) — matches Cloud66's deploy hook
# - nodejs: JS runtime for execjs. coffee-rails (deprecated, still in the default
#   group) needs a runtime to load at boot — both during assets:precompile in the
#   build stage and at server boot in the final stage. Cloud66 provides node too.
# - wget: db/seeds runs `rake setup:import_manufacturers_csv` etc., which download
#   CSVs via wget (lib/tasks/setup_tasks.rake) during db:prepare's seed step.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      cron \
      curl \
      imagemagick \
      libjemalloc2 \
      libvips \
      libyaml-0-2 \
      nodejs \
      postgresql-client \
      ripgrep \
      wget && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# This image only ships to review apps, which run RAILS_ENV=staging
# (see config/deploy.review.yml + config/environments/staging.rb). Building in
# staging keeps build-time (asset precompile, bootsnap) and run-time consistent.
ENV RAILS_ENV="staging" \
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
# Sprockets' incremental cache is a BuildKit cache mount: `COPY . .` invalidates
# this layer on every commit, but the mount persists across CI runs (via
# buildkit-cache-dance in review-app.yml), so only changed assets recompile.
# Mounts never land in the layer, which also keeps the build-time-only cache out
# of the image that's pushed to GHCR and pulled by the review host every deploy.
# tmp/cache/bootsnap stays in-layer on purpose — shipping it is the point of the
# bootsnap precompile steps above.
RUN --mount=type=cache,target=/rails/tmp/cache/assets \
    SECRET_KEY_BASE=dummy REDIS_URL="redis://localhost:6379" ./bin/rails assets:precompile

# Final stage
FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
# bin/docker-entrypoint keys role-creation + db:prepare off the last two args
# being `./bin/rails server` — if you change CMD (e.g. to bin/jobs), update the
# entrypoint's guard too or per-PR Postgres roles will stop being provisioned.
CMD ["./bin/thrust", "./bin/rails", "server"]
