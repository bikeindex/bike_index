# syntax=docker/dockerfile:1
# check=error=true

# Tooling image for CI's `test` job (see ../workflows/ci.yml). Bakes the OS
# packages, Node runtime, and Playwright's Chromium + OS deps that otherwise
# get reinstalled from scratch on every one of the 5 parallel test shards.
#
# Ruby itself is deliberately NOT baked here: ruby/setup-ruby's own cached
# install is already fast and also manages the gem cache, so duplicating it
# would be dead weight. Gems and npm packages aren't baked either — they
# change on every dependency bump, while these inputs change rarely, and
# bundle/npm install already run fast off actions/cache.
#
# Rebuilt automatically (ci.yml's build_ci_image job) whenever this file,
# .tool-versions, or package.json changes.

FROM docker.io/library/debian:bookworm-slim

# Matches ci.yml's former "Install system dependencies" step (imagemagick,
# libvips, curl, gettext, libcurl4-gnutls-dev, libexpat1-dev, libssl-dev,
# libz-dev, postgresql-client, ripgrep), plus packages the GitHub-hosted
# runner ships preinstalled that this minimal base doesn't: build-essential/
# libpq-dev/libyaml-dev/pkg-config (native gem compilation, e.g. pg), git
# (required by actions/checkout inside a container job), ca-certificates and
# xz-utils (fetching/unpacking Node below).
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      ca-certificates \
      curl \
      gettext \
      git \
      imagemagick \
      libcurl4-gnutls-dev \
      libexpat1-dev \
      libpq-dev \
      libssl-dev \
      libvips \
      libyaml-dev \
      libz-dev \
      pkg-config \
      postgresql-client \
      ripgrep \
      xz-utils && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Node, matching .tool-versions (see .cloud66/manifest.yml for the other pin)
ARG NODE_VERSION=24.15.0
RUN curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" && \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 && \
    rm /tmp/node.tar.xz

# Playwright's Chromium + its OS-level deps, pinned to package.json's version.
# PLAYWRIGHT_BROWSERS_PATH is fixed (not under $HOME): GitHub Actions
# container jobs remap HOME to a runner-mounted path at job time, so a
# HOME-relative cache baked at build time wouldn't be visible at runtime.
ARG PLAYWRIGHT_VERSION=1.60.0
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
RUN npx --yes playwright@$PLAYWRIGHT_VERSION install --with-deps chromium && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
