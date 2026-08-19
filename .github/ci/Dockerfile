# syntax=docker/dockerfile:1
# check=error=true

# Tooling image for CI's `test` job (see ../workflows/ci.yml). Bakes Ruby, the OS
# packages, Node, the gems, node_modules, and Playwright's Chromium + OS deps —
# everything that otherwise gets reinstalled or restored from cache on each of
# the 5 parallel test shards.
#
# Ruby is baked here (not left to ruby/setup-ruby) because that action
# downloads a prebuilt binary sized for the full GitHub-hosted runner image —
# inside a minimal container it fails to dynamically link
# ("libruby.so.4.0: cannot open shared object file"). The official `ruby`
# image (same one the root Dockerfile builds review apps from) doesn't have
# that problem.
#
# Rebuilt automatically (ci.yml's build_ci_image job) whenever this file,
# .tool-versions, package.json, Gemfile.lock or package-lock.json changes.

ARG RUBY_VERSION=4.0.6

FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

ENV BUNDLE_PATH=/usr/local/bundle \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright

# Runtime packages only — the compile toolchain lives in `dependencies` below and
# never reaches the final image, which every shard pays to pull. Mirrors the root
# Dockerfile's runtime set (libvips for ruby-vips, imagemagick for mini_magick,
# libpq5 via postgresql-client for pg), plus what a container job needs that a
# runner would have brought: git for actions/checkout and the Gemfile's `github:`
# gems, and curl/ca-certificates/xz-utils to fetch Node and gh.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      gettext \
      git \
      imagemagick \
      libvips \
      libyaml-0-2 \
      ripgrep \
      xz-utils && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Node, matching .tool-versions (see .cloud66/manifest.yml for the other pin)
ARG NODE_VERSION=24.15.0
RUN curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" && \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 && \
    rm /tmp/node.tar.xz

FROM base AS dependencies

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libcurl4-gnutls-dev \
      libexpat1-dev \
      libffi-dev \
      libpq-dev \
      libssl-dev \
      libyaml-dev \
      libz-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Same cleanup the root Dockerfile does: the .gem archives are dead weight once
# the gems are installed, and the `github:` gems' .git directories with them.
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 && \
    rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# At / because the runner mounts its own workspace over the checkout path at job
# time, so anything installed there at build time would be hidden. ci.yml
# symlinks it back to ./node_modules for the callers that name that path —
# `npx playwright` and spec/support/axe.rb.
COPY package.json package-lock.json /
RUN npm ci --no-audit --no-fund

FROM base AS final

# The GitHub CLI, which every other job and bin/ script in this repo reaches for
# — those run on the runner, which ships it; a container job has to bake it.
# bin/check_translations is the one that needs it here. Man pages left behind.
ARG GH_VERSION=2.97.0
RUN curl -fsSLo /tmp/gh.tar.gz "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" && \
    tar -xzf /tmp/gh.tar.gz -C /usr/local --strip-components=1 --wildcards '*/bin/gh' && \
    rm /tmp/gh.tar.gz

# Postgres and redis run inside this container rather than as service
# containers, which cost ~10s of registry pulls per shard. Postgres comes from
# PGDG because trixie ships 17 and this has to be the 16 that development and
# production run — it also supplies the psql and pg_dump that db:schema:load
# and the structure.sql dump shell out to, which have to match the server.
# Redis is trixie's own 8; the service container pinned 7 to match the
# review-app accessory, and CI is free to move ahead of it.
ARG PG_VERSION=16
RUN install -d /usr/share/postgresql-common/pgdg && \
    curl -fsSLo /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
      https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt trixie-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      "postgresql-${PG_VERSION}" \
      redis-server && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
ENV PATH="/usr/lib/postgresql/${PG_VERSION}/bin:${PATH}"

COPY --from=dependencies /usr/local/bundle /usr/local/bundle
COPY --from=dependencies /node_modules /node_modules

# Driven by the playwright baked above rather than `npx playwright@<version>`, so
# the browser can't drift from the package-lock.json the gems were built against.
RUN /node_modules/.bin/playwright install --with-deps chromium && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
