#!/bin/bash
# One-shot setup for the Claude Code web sandbox (/home/user/bike_index).
#
#   bash .claude/skills/sandbox-test-setup/assets/web_sandbox_setup.sh [--dev-server]
#
# Gets the toolchain in place, then hands off to `bin/workspace_setup --without_seeds`
# for the gems, node_modules and databases. Everything that can overlap does: the
# prebuilt downloads, the apt/services/chrome work that needs no Ruby, and (when no
# prebuilt Ruby is reachable) the source build all run at once.
# Idempotent: re-running it after a container idle period just restarts the
# services. Pass --dev-server to also boot bin/dev in the background.
#
# Logs: /tmp/ruby_build.log, /tmp/system_setup.log, /tmp/css_build.log, /tmp/dev_server.log
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-/home/user/bike_index}"
RUBYVER=$(awk '$1=="ruby"{print $2}' "$REPO/.tool-versions")
LOCK_SHA=$(sha256sum "$REPO/Gemfile.lock" | cut -c1-12)
NPM_SHA=$(sha256sum "$REPO/package-lock.json" | cut -c1-12)
# rbconfig bakes the prefix in, so the tarball has to land where it was built:
# ruby/setup-ruby's toolcache path. /opt/ruby-<ver>/x64 stays as a symlink to it.
TOOLCACHE="/opt/hostedtoolcache/Ruby/${RUBYVER}"
RUBY_PREFIX="/opt/ruby-${RUBYVER}/x64"
PREBUILT_BASE="${BINX_PREBUILT_BASE:-https://github.com/bikeindex/bike_index/releases/download/web-sandbox-prebuilt}"

RUBY_TARBALL="ruby-${RUBYVER}-ubuntu24.04-x86_64.tar.gz"
BUNDLE_TARBALL="bundle-${RUBYVER}-${LOCK_SHA}-ubuntu24.04-x86_64.tar.gz"
# main's Gemfile.lock moves often enough that an exact miss is the common case, so
# fall back to the newest published bundle: `bundle install` then fetches the few
# gems that differ instead of all of them.
BUNDLE_LATEST="bundle-${RUBYVER}-latest-ubuntu24.04-x86_64.tar.gz"
NODE_TARBALL="node_modules-${NPM_SHA}-ubuntu24.04.tar.gz"

export PATH="$RUBY_PREFIX/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="$RUBY_PREFIX/lib:${LD_LIBRARY_PATH:-}"
export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
export PGHOST=127.0.0.1 PGUSER=rails PGPASSWORD=password
export LANG=C.UTF-8 LC_ALL=C.UTF-8

say() { echo "==> $*"; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# ------------------------------------------------------------ prebuilt assets
# .github/workflows/web-sandbox-prebuild.yml publishes these; every failure here
# is non-fatal, because building from source is always still an option.
download_asset() { # <tarball>... — first one that resolves wins, verified into $STAGE
  [ "${BINX_SKIP_PREBUILT:-}" != "1" ] || return 1
  local tarball
  for tarball in "$@"; do
    curl -sfL --max-time 600 -o "$STAGE/$tarball" "$PREBUILT_BASE/$tarball" &&
      curl -sfL --max-time 60 -o "$STAGE/$tarball.sha256" "$PREBUILT_BASE/$tarball.sha256" &&
      (cd "$STAGE" && sha256sum -c "$tarball.sha256" >/dev/null) &&
      { printf '%s' "$tarball" > "$STAGE/$1.resolved"; return 0; }
    rm -f "$STAGE/$tarball" "$STAGE/$tarball.sha256"
  done
  return 1
}

# Which name a download job settled on (its fallback, or nothing at all). The jobs
# are subshells, so the filesystem is how they report back.
resolved_asset() { cat "$STAGE/$1.resolved" 2>/dev/null; }

link_ruby_prefix() {
  # A half-built prefix left by a timed-out session would shadow what we just
  # unpacked, so move it aside rather than letting the rebuild path win.
  [ -L "$RUBY_PREFIX" ] || [ ! -e "$RUBY_PREFIX" ] || mv "$RUBY_PREFIX" "$RUBY_PREFIX.broken.$$"
  mkdir -p "$(dirname "$RUBY_PREFIX")"
  ln -sfn "$TOOLCACHE/x64" "$RUBY_PREFIX"
}

unpack_ruby_tree() { # <tarball> — both Ruby and bundle assets extract over $TOOLCACHE
  [ -s "$STAGE/$1" ] || return 1
  mkdir -p "$TOOLCACHE" && tar -C "$TOOLCACHE" -xzf "$STAGE/$1"
}

ruby_is_built() { "$RUBY_PREFIX/bin/ruby" --version 2>/dev/null | grep -q "^ruby ${RUBYVER}"; }

# ---------------------------------------------------------------- ruby build
build_ruby() {
  set -e
  local src="/tmp/ruby-build-src/ruby-${RUBYVER}"
  mkdir -p /tmp/ruby-build-src
  # The archive tarball endpoint 403s through the proxy; git-over-https works.
  [ -d "$src" ] || git clone --depth 1 --branch "v${RUBYVER}" \
    https://github.com/ruby/ruby.git "$src"
  cd "$src"
  [ -f configure ] || ./autogen.sh
  # Pre-stage the bundled gems `make install` would fetch through rubygems'
  # own cert store. 8 at a time - serially this is a minute of latency.
  awk '$1 !~ /^#/ && NF {print $1, $2}' gems/bundled_gems \
    | xargs -P8 -n2 bash -c '[ -s "gems/$0-$1.gem" ] || curl -sfL --max-time 60 \
        -o "gems/$0-$1.gem" "https://rubygems.org/downloads/$0-$1.gem"'
  mkdir -p /tmp/ruby-build-src/build && cd /tmp/ruby-build-src/build
  [ -f Makefile ] || "$src/configure" --prefix="$RUBY_PREFIX" \
    --enable-shared --disable-install-doc --with-openssl-dir=/usr
  make -j"$(nproc)"
  SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt make install
  # Some shebangs assume the GitHub-Actions hostedtoolcache layout
  mkdir -p "$TOOLCACHE"
  [ -e "$TOOLCACHE/x64" ] || ln -s "$RUBY_PREFIX" "$TOOLCACHE/x64"
  "$RUBY_PREFIX/bin/ruby" --version
}

# ------------------------------------- everything that needs no Ruby, in parallel
setup_system() {
  # ruby-vips loads at boot, so without libvips every rails/rspec run dies
  if ! ldconfig -p | grep -q libvips.so.42; then
    apt-get install -y libvips42 ||
      { apt-get update && apt-get install -y libvips42; }
  fi

  service postgresql start >/dev/null   # redis logs a benign ulimit warning
  service redis-server start 2>&1 | grep -v ulimit
  sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='rails'" | grep -q 1 ||
    sudo -u postgres psql -c "CREATE USER rails WITH SUPERUSER PASSWORD 'password';"

  # Playwright MCP's chrome: fixed path, --no-sandbox (we are root), auth file
  local chrome_dir
  chrome_dir="$(ls -d /opt/pw-browsers/chromium-*/chrome-linux 2>/dev/null | sort -V | tail -1)"
  mkdir -p /root/.cache/ms-playwright
  if [ -x "$chrome_dir/chrome" ]; then
    mkdir -p /opt/google/chrome
    printf '#!/bin/bash\nexec "%s" --no-sandbox --disable-dev-shm-usage "$@"\n' "$chrome_dir/chrome" \
      > /opt/google/chrome/chrome
    chmod +x /opt/google/chrome/chrome
  else
    echo "no chromium under /opt/pw-browsers - MCP screenshots will not work"
  fi
  [ -s /root/.cache/ms-playwright/mcp-auth.json ] ||
    printf '{"cookies":[],"origins":[]}' > /root/.cache/ms-playwright/mcp-auth.json
}

say "starting system setup, prebuilt downloads and (if needed) the ruby build together"
setup_system > /tmp/system_setup.log 2>&1 &
SYSTEM_PID=$!

RUBY_DL_PID=""
ruby_is_built || { download_asset "$RUBY_TARBALL" & RUBY_DL_PID=$!; }
download_asset "$BUNDLE_TARBALL" "$BUNDLE_LATEST" &
BUNDLE_DL_PID=$!
download_asset "$NODE_TARBALL" &
NODE_DL_PID=$!

# ---------------------------------------------------------------------- ruby
RUBY_PID=""
if ruby_is_built; then
  say "ruby ${RUBYVER} already installed"
elif wait "$RUBY_DL_PID" && unpack_ruby_tree "$RUBY_TARBALL" && link_ruby_prefix && ruby_is_built; then
  say "prebuilt ruby ${RUBYVER} installed"
else
  say "no prebuilt ruby - building from source in the background (~6 min on 4 cores) -> /tmp/ruby_build.log"
  build_ruby > /tmp/ruby_build.log 2>&1 &
  RUBY_PID=$!
fi

# The gem tree extracts over the Ruby's own GEM_HOME, so it waits on whichever
# Ruby path won - but the download has been running since the top either way.
install_prebuilt_gems() {
  local resolved
  resolved=$(resolved_asset "$BUNDLE_TARBALL")
  [ -n "$resolved" ] || return 0
  unpack_ruby_tree "$resolved" || return 0
  # Only when nothing has claimed the prefix yet: after a source build it's a real
  # directory that $TOOLCACHE/x64 points AT, and relinking would chase its own tail.
  ruby_is_built || link_ruby_prefix
  case "$resolved" in
    "$BUNDLE_TARBALL") say "prebuilt gems for Gemfile.lock ${LOCK_SHA} installed" ;;
    *) say "no bundle for Gemfile.lock ${LOCK_SHA}; unpacked the latest one, bundle install will reconcile" ;;
  esac
}

if [ -n "$RUBY_PID" ]; then
  say "waiting on the ruby build"
  wait "$RUBY_PID" || { echo "ruby build FAILED - see /tmp/ruby_build.log"; tail -20 /tmp/ruby_build.log; exit 1; }
  say "ruby $("$RUBY_PREFIX/bin/ruby" -e 'print RUBY_VERSION') built"
fi

wait "$BUNDLE_DL_PID"
install_prebuilt_gems

cd "$REPO"

# Unpacked before bin/setup's `npm install`, which then reconciles a near-miss
# instead of fetching all 292 packages. bin/lint (herb-format, standard) and the
# :js specs' playwright package both need this tree.
wait "$NODE_DL_PID"
if [ -n "$(resolved_asset "$NODE_TARBALL")" ] && tar -C "$REPO" -xzf "$STAGE/$NODE_TARBALL"; then
  say "prebuilt node_modules for package-lock ${NPM_SHA} installed"
fi

# workspace_setup wants postgres up and the rails role in place before it can
# allocate an ID out of the dev_workspaces database.
wait "$SYSTEM_PID" || say "system setup had a problem - see /tmp/system_setup.log"

# bin/workspace_setup assigns .workspace_id, then hands off to bin/setup for
# bundler, `bundle install`, `npm install` and the databases (db:create,
# schema:load on primary AND analytics, db:migrate). Everything above exists to
# make its steps no-ops: a prebuilt Ruby for its version check, prebuilt gems for
# its `bundle check`, a prebuilt node_modules for its `npm install`. --without_seeds
# skips db:seed, which needs `setup:import_spreadsheets` and so a network this
# sandbox doesn't have.
say "bin/workspace_setup --without_seeds"
bin/workspace_setup --without_seeds || exit 1

# After workspace_setup, not before: .workspace_id is what gives BASE_URL its port.
eval "$(ruby bin/env --export)"

# bin/setup builds dartsass only on the seeding path, and tailwind not at all.
# Without them anything rendering the application layout - a request spec on an
# html format, any :js system spec - dies on AssetNotFound. ~15s; bin/dev's
# watchers keep them current afterwards.
say "building tailwind + dartsass"
bundle exec rails tailwindcss:build dartsass:build >/tmp/css_build.log 2>&1 ||
  say "css build failed - see /tmp/css_build.log (layout-rendering specs will fail until it works)"

if [ "${1:-}" = "--dev-server" ]; then
  say "starting bin/dev -> /tmp/dev_server.log"
  nohup bin/dev > /tmp/dev_server.log 2>&1 &
  # First boot compiles assets, ~40s. Bounded, so a server that dies on boot
  # reports its log instead of hanging the session hook until its timeout.
  for _ in $(seq 1 48); do curl -fs -o /dev/null "$BASE_URL/" && break; sleep 5; done
  if curl -fs -o /dev/null "$BASE_URL/"; then
    say "dev server up at $BASE_URL"
  else
    say "dev server never answered on $BASE_URL - see /tmp/dev_server.log"
    tail -20 /tmp/dev_server.log
  fi
fi

ENV_EXPORTS=$(cat <<EOF
export PATH="$RUBY_PREFIX/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="$RUBY_PREFIX/lib:\${LD_LIBRARY_PATH:-}"
export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
export PGHOST=127.0.0.1 PGUSER=rails PGPASSWORD=password
export LANG=C.UTF-8 LC_ALL=C.UTF-8
EOF
)

# Set by the SessionStart hook: everything written here is exported into the
# session's shells, so later commands need no `export PATH=...` preamble.
if [ -n "${CLAUDE_ENV_FILE:-}" ] && ! grep -qF "$RUBY_PREFIX/bin" "$CLAUDE_ENV_FILE" 2>/dev/null; then
  printf '%s\n' "$ENV_EXPORTS" >> "$CLAUDE_ENV_FILE"
  say "wrote the toolchain env to \$CLAUDE_ENV_FILE"
fi

say "done. Shell env for later commands:"
cat <<EOF
  export PATH="$RUBY_PREFIX/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
  export LD_LIBRARY_PATH="$RUBY_PREFIX/lib:\$LD_LIBRARY_PATH"
  export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
  export PGHOST=127.0.0.1 PGUSER=rails PGPASSWORD=password LANG=C.UTF-8 LC_ALL=C.UTF-8
  eval "\$(ruby bin/env --export)"
EOF
