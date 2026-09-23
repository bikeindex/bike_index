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
# gems that differ instead of all of them. This one names that tarball rather than
# being a second copy of it - the bundle is ~270MB.
BUNDLE_LATEST_POINTER="bundle-${RUBYVER}-latest.txt"
NODE_TARBALL="node_modules-${NPM_SHA}-ubuntu24.04.tar.gz"

# Authored once: used here, appended to $CLAUDE_ENV_FILE, and printed at the end.
ENV_EXPORTS="export PATH=\"$RUBY_PREFIX/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin\"
export LD_LIBRARY_PATH=\"$RUBY_PREFIX/lib:\${LD_LIBRARY_PATH:-}\"
export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
export PGHOST=127.0.0.1 PGUSER=rails PGPASSWORD=password
export LANG=C.UTF-8 LC_ALL=C.UTF-8"
eval "$ENV_EXPORTS"

say() { echo "==> $*"; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# ------------------------------------------------------------ prebuilt assets
# .github/workflows/web-sandbox-prebuild.yml publishes these; every failure here
# is non-fatal, because building from source is always still an option.
download_asset() { # <tarball> — verified into $STAGE
  local tarball="$1" code
  [ "${BINX_SKIP_PREBUILT:-}" != "1" ] || { echo "skip $tarball (BINX_SKIP_PREBUILT)" >> "$STAGE/prebuilt.log"; return 1; }
  # -f decides; the code is only so the log can tell a blocked host from a 404.
  code=$(curl -sfL --max-time 600 -o "$STAGE/$tarball" -w '%{http_code}' "$PREBUILT_BASE/$tarball") || code="${code:-000}"
  if [ -s "$STAGE/$tarball" ] &&
    curl -sfL --max-time 60 -o "$STAGE/$tarball.sha256" "$PREBUILT_BASE/$tarball.sha256" &&
    (cd "$STAGE" && sha256sum -c "$tarball.sha256" >/dev/null); then
    echo "hit  $tarball" >> "$STAGE/prebuilt.log"
    return 0
  fi
  # 000 is the tell that matters: no HTTP answer at all, i.e. the egress proxy
  # refused the host rather than the release not having the asset.
  echo "miss $tarball (http $code)" >> "$STAGE/prebuilt.log"
  rm -f "$STAGE/$tarball" "$STAGE/$tarball.sha256"
  return 1
}

# Release assets redirect to release-assets.githubusercontent.com, which is not on
# the sandbox's allow list - so a blocked host makes every download miss and every
# session pay the 6-minute source build. Say so rather than letting it look normal.
report_prebuilt() {
  say "prebuilt assets:"
  sed 's/^/    /' "$STAGE/prebuilt.log" 2>/dev/null
  if ! grep -q '^hit' "$STAGE/prebuilt.log" 2>/dev/null &&
    grep -q 'http 000' "$STAGE/prebuilt.log" 2>/dev/null; then
    say "NOTHING resolved and the host never answered - $PREBUILT_BASE looks unreachable"
    say "  probe it: curl -sI -o /dev/null -w '%{http_code}\n' $PREBUILT_BASE/$RUBY_TARBALL"
    say "  point BINX_PREBUILT_BASE at a reachable host to skip the source build"
  fi
}

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

DEV_SERVER=0
[ "${1:-}" != "--dev-server" ] || DEV_SERVER=1

say "starting system setup, prebuilt downloads and (if needed) the ruby build together"
setup_system > /tmp/system_setup.log 2>&1 &
SYSTEM_PID=$!

# Named by whichever bundle download won, so the unpack knows what to open.
BUNDLE_WON="$STAGE/bundle.name"

download_bundle() {
  local won="$BUNDLE_TARBALL"
  if ! download_asset "$won"; then
    won=$(curl -sfL --max-time 60 "$PREBUILT_BASE/$BUNDLE_LATEST_POINTER")
    [ -n "$won" ] && [ "$won" != "$BUNDLE_TARBALL" ] || return 1
    download_asset "$won" || return 1
  fi
  printf '%s' "$won" > "$BUNDLE_WON"
}

# Stamps let a warm container - a resume, or a hand re-run - skip the download and
# extraction of trees that are already correct. Each lives inside the tree it
# vouches for, so anything that removes the tree removes the claim with it.
GEM_STAMP="$TOOLCACHE/x64/lib/ruby/gems/.binx_lock_sha"
NPM_STAMP="$REPO/node_modules/.binx_npm_sha"
stamped() { [ "$(cat "$1" 2>/dev/null)" = "$2" ]; }

# Fused onto its own download below, because node_modules needs neither the Ruby
# nor the gem tree - so on the source-build path it lands during those six minutes
# rather than after them. bin/setup's `npm install` reconciles whatever it leaves
# short; bin/lint and the :js specs' playwright package both need the tree.
unpack_node() {
  tar -C "$REPO" -xzf "$STAGE/$NODE_TARBALL" || return 1
  say "prebuilt node_modules for package-lock ${NPM_SHA} installed"
}

RUBY_DL_PID=""
BUNDLE_DL_PID=""
NODE_DL_PID=""
ruby_is_built || { download_asset "$RUBY_TARBALL" & RUBY_DL_PID=$!; }
stamped "$GEM_STAMP" "$LOCK_SHA" || { download_bundle & BUNDLE_DL_PID=$!; }
stamped "$NPM_STAMP" "$NPM_SHA" || { download_asset "$NODE_TARBALL" && unpack_node & NODE_DL_PID=$!; }

# ---------------------------------------------------------------------- ruby
RUBY_PID=""
if [ -z "$RUBY_DL_PID" ]; then
  say "ruby ${RUBYVER} already installed"
elif wait "$RUBY_DL_PID" && unpack_ruby_tree "$RUBY_TARBALL" && link_ruby_prefix && ruby_is_built; then
  say "prebuilt ruby ${RUBYVER} installed"
else
  say "no prebuilt ruby - building from source in the background (~6 min on 4 cores) -> /tmp/ruby_build.log"
  build_ruby > /tmp/ruby_build.log 2>&1 &
  RUBY_PID=$!
fi

if [ -n "$RUBY_PID" ]; then
  say "waiting on the ruby build"
  wait "$RUBY_PID" || { echo "ruby build FAILED - see /tmp/ruby_build.log"; tail -20 /tmp/ruby_build.log; exit 1; }
  say "ruby $("$RUBY_PREFIX/bin/ruby" -e 'print RUBY_VERSION') built"
fi

cd "$REPO"

# The two trees are disjoint, so they unpack at the same time. The gem one goes
# over the Ruby's own GEM_HOME, which is why it waited for the Ruby to land.
unpack_gems() {
  local won
  won=$(cat "$BUNDLE_WON" 2>/dev/null)
  [ -n "$won" ] && unpack_ruby_tree "$won" || return 0
  # Only when nothing has claimed the prefix yet: after a source build it's a real
  # directory that $TOOLCACHE/x64 points AT, and relinking would chase its own tail.
  ruby_is_built || link_ruby_prefix
  if [ "$won" = "$BUNDLE_TARBALL" ]; then
    say "prebuilt gems for Gemfile.lock ${LOCK_SHA} installed"
  else
    say "no bundle for Gemfile.lock ${LOCK_SHA}; unpacked ${won}, bundle install will reconcile"
  fi
}

[ -z "$BUNDLE_DL_PID" ] || { wait "$BUNDLE_DL_PID"; unpack_gems; }
[ -z "$NODE_DL_PID" ] || wait "$NODE_DL_PID"

# workspace_setup wants postgres up and the rails role in place before it can
# allocate an ID out of the dev_workspaces database.
wait "$SYSTEM_PID" || say "system setup had a problem - see /tmp/system_setup.log"
report_prebuilt

# Everything above exists to make this a no-op: bin/setup checks the Ruby version,
# runs `bundle check` and `npm install`. --without_seeds because db:seed needs
# `setup:import_spreadsheets`, and so a network this sandbox doesn't have.
say "bin/workspace_setup --without_seeds"
bin/workspace_setup --without_seeds || exit 1

# After workspace_setup, not before: .workspace_id is what gives BASE_URL its port.
eval "$(ruby bin/env --export)"

# bin/setup builds dartsass only on the seeding path, and tailwind not at all, and
# without them anything rendering the application layout - a request spec on an html
# format, any :js system spec - dies on AssetNotFound. Under --dev-server it is
# Procfile.dev's dartsass:watch and tailwindcss:watch that build them instead.
if [ "$DEV_SERVER" = 1 ]; then
  say "starting bin/dev -> /tmp/dev_server.log; its watchers build the css"
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
else
  say "building tailwind + dartsass"
  bundle exec rails tailwindcss:build dartsass:build >/tmp/css_build.log 2>&1 ||
    say "css build failed - see /tmp/css_build.log (layout-rendering specs will fail until it works)"
fi

# Stamped here rather than at unpack, and unconditionally: what makes each tree
# match its lockfile is bin/setup's `bundle install` and `npm install`, not which
# prebuilt landed. A run that dies before this point re-downloads next time.
printf '%s' "$LOCK_SHA" > "$GEM_STAMP"
printf '%s' "$NPM_SHA" > "$NPM_STAMP"

# Set by the SessionStart hook: everything written here is exported into the
# session's shells, so later commands need no `export PATH=...` preamble.
if [ -n "${CLAUDE_ENV_FILE:-}" ] && ! grep -qF "$RUBY_PREFIX/bin" "$CLAUDE_ENV_FILE" 2>/dev/null; then
  printf '%s\n' "$ENV_EXPORTS" >> "$CLAUDE_ENV_FILE"
  say "wrote the toolchain env to \$CLAUDE_ENV_FILE"
fi

say "done. Shell env for later commands:"
printf '%s\n' "$ENV_EXPORTS" 'eval "$(ruby bin/env --export)"' | sed 's/^/  /' 
