# syntax=docker/dockerfile:1
# check=error=true

# Tooling image for CI's `test` job (see ../workflows/ci.yml). Bakes Ruby, the
# OS packages, the Node runtime, and Playwright's Chromium + OS deps that
# otherwise get reinstalled from scratch on every one of the 5 parallel test
# shards.
#
# Ruby is baked here (not left to ruby/setup-ruby) because that action
# downloads a prebuilt binary sized for the full GitHub-hosted runner image —
# inside a minimal container it fails to dynamically link
# ("libruby.so.4.0: cannot open shared object file"). The official `ruby`
# image (same one the root Dockerfile builds review apps from) doesn't have
# that problem. Gems and npm packages still aren't baked — they change on
# every dependency bump, while these inputs change rarely, and bundle/npm
# install already run fast off actions/cache.
#
# Rebuilt automatically (ci.yml's build_ci_image job) whenever this file,
# .tool-versions, or package.json changes.

ARG RUBY_VERSION=4.0.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim

ENV BUNDLE_PATH=/usr/local/bundle

# Matches ci.yml's former "Install system dependencies" step (imagemagick,
# libvips, curl, gettext, libcurl4-gnutls-dev, libexpat1-dev, libssl-dev,
# libz-dev, postgresql-client, ripgrep), plus packages the GitHub-hosted
# runner ships preinstalled that this slim base doesn't: build-essential/
# libpq-dev/libyaml-dev/libffi-dev/pkg-config (native gem compilation, e.g.
# pg, fiddle), git (required by actions/checkout inside a container job),
# ca-certificates and xz-utils (fetching/unpacking Node below).
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
      libffi-dev \
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

# The GitHub CLI, which every other job and bin/ script in this repo reaches for
# — those run on the runner, which ships it; a container job has to bake it.
# bin/check_translations is the one that needs it here. Man pages left behind.
ARG GH_VERSION=2.97.0
RUN curl -fsSLo /tmp/gh.tar.gz "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" && \
    tar -xzf /tmp/gh.tar.gz -C /usr/local --strip-components=1 --wildcards '*/bin/gh' && \
    rm /tmp/gh.tar.gz

# Playwright's Chromium + its OS-level deps, pinned to package.json's version.
# PLAYWRIGHT_BROWSERS_PATH is fixed (not under $HOME): GitHub Actions
# container jobs remap HOME to a runner-mounted path at job time, so a
# HOME-relative cache baked at build time wouldn't be visible at runtime.
ARG PLAYWRIGHT_VERSION=1.60.0
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
RUN npx --yes playwright@$PLAYWRIGHT_VERSION install --with-deps chromium && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
