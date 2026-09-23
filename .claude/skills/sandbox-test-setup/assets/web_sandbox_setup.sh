#!/bin/bash
# One-shot setup for the Claude Code web sandbox (/home/user/bike_index).
#
#   bash .claude/skills/sandbox-test-setup/assets/web_sandbox_setup.sh [--dev-server]
#
# Toolchain, then `bin/workspace_setup --without_seeds` and a background seed
# of an empty development database (/tmp/seed.status). Idempotent; --dev-server also
# boots bin/dev.
#
# Logs: /tmp/ruby_build.log, /tmp/system_setup.log, /tmp/playwright_install.log,
#       /tmp/seed.log (+ /tmp/seed.status), /tmp/dev_server.log
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-/home/user/bike_index}"
RUBYVER=$(awk '$1=="ruby"{print $2}' "$REPO/.tool-versions")
LOCK_SHA=$(sha256sum "$REPO/Gemfile.lock" | cut -c1-12)
NPM_SHA=$(sha256sum "$REPO/package-lock.json" | cut -c1-12)
# rbconfig bakes the prefix in, so the tarball lands where it was built (setup-ruby's
# toolcache); /opt/ruby-<ver>/x64 symlinks to it.
TOOLCACHE="/opt/hostedtoolcache/Ruby/${RUBYVER}"
RUBY_PREFIX="/opt/ruby-${RUBYVER}/x64"
PREBUILT_BASE="${BINX_PREBUILT_BASE:-https://github.com/bikeindex/bike_index/releases/download/web-sandbox-prebuilt}"

RUBY_TARBALL="ruby-${RUBYVER}-ubuntu24.04-x86_64.tar.gz"
BUNDLE_TARBALL="bundle-${RUBYVER}-${LOCK_SHA}-ubuntu24.04-x86_64.tar.gz"
# An exact-lock miss is common, so fall back to the newest bundle and let `bundle
# install` fetch the difference. A pointer, not a ~270MB second copy.
BUNDLE_LATEST_POINTER="bundle-${RUBYVER}-latest.txt"
NODE_TARBALL="node_modules-${NPM_SHA}-ubuntu24.04.tar.gz"

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
# Published by .github/workflows/web-sandbox-prebuild.yml. Non-fatal: source builds remain.
download_asset() { # <tarball> — verified into $STAGE
  local tarball="$1" code
  [ "${BINX_SKIP_PREBUILT:-}" != "1" ] || { echo "skip $tarball (BINX_SKIP_PREBUILT)" >> "$STAGE/prebuilt.log"; return 1; }
  code=$(curl -sfL --max-time 600 -o "$STAGE/$tarball" -w '%{http_code}' "$PREBUILT_BASE/$tarball") || code="${code:-000}"
  if [ -s "$STAGE/$tarball" ] &&
    curl -sfL --max-time 60 -o "$STAGE/$tarball.sha256" "$PREBUILT_BASE/$tarball.sha256" &&
    (cd "$STAGE" && sha256sum -c "$tarball.sha256" >/dev/null); then
    echo "hit  $tarball" >> "$STAGE/prebuilt.log"
    return 0
  fi
  # 000: the network policy refused the host, rather than the asset being missing
  echo "miss $tarball (http $code)" >> "$STAGE/prebuilt.log"
  rm -f "$STAGE/$tarball" "$STAGE/$tarball.sha256"
  return 1
}

# A refused release-assets.githubusercontent.com otherwise looks like a normal miss
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
  # A half-built prefix from a timed-out session would shadow the unpacked tree
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
  # The release tarball ships ./configure and the bundled gems; the tag is the fallback
  [ -d "$src" ] || curl -sfL --max-time 300 "https://cache.ruby-lang.org/pub/ruby/${RUBYVER%.*}/ruby-${RUBYVER}.tar.gz" \
    | tar -C /tmp/ruby-build-src -xz || { rm -rf "$src"; false; } ||
    git clone --depth 1 --branch "v${RUBYVER}" https://github.com/ruby/ruby.git "$src"
  cd "$src"
  [ -f configure ] || ./autogen.sh
  # A git checkout lacks the bundled gems, and `make install` would fetch them through
  # rubygems' own cert store, which the proxy breaks
  awk '$1 !~ /^#/ && NF {print $1, $2}' gems/bundled_gems \
    | xargs -P8 -n2 bash -c '[ -s "gems/$0-$1.gem" ] || curl -sfL --max-time 60 \
        -o "gems/$0-$1.gem" "https://rubygems.org/downloads/$0-$1.gem"'
  mkdir -p /tmp/ruby-build-src/build && cd /tmp/ruby-build-src/build
  [ -f Makefile ] || "$src/configure" --prefix="$RUBY_PREFIX" \
    --enable-shared --disable-install-doc --with-openssl-dir=/usr
  make -j"$(nproc)"
  SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt make install
  mkdir -p "$TOOLCACHE"
  [ -e "$TOOLCACHE/x64" ] || ln -s "$RUBY_PREFIX" "$TOOLCACHE/x64"
  "$RUBY_PREFIX/bin/ruby" --version
}

# ------------------------------------- everything that needs no Ruby, in parallel
setup_system() {
  # libvips: ruby-vips loads at boot. imagemagick: db:seed's avatars need `identify`.
  local pkgs=()
  ldconfig -p | grep -q libvips.so.42 || pkgs+=(libvips42)
  command -v identify >/dev/null || pkgs+=(imagemagick)
  if [ "${#pkgs[@]}" -gt 0 ]; then
    apt-get install -y --no-install-recommends "${pkgs[@]}" ||
      { apt-get update && apt-get install -y --no-install-recommends "${pkgs[@]}"; }
  fi

  service postgresql start >/dev/null
  service redis-server start 2>&1 | grep -v ulimit
  sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='rails'" | grep -q 1 ||
    sudo -u postgres psql -c "CREATE USER rails WITH SUPERUSER PASSWORD 'password';"

  # Playwright MCP's `chrome` channel: fixed path, and --no-sandbox because we're root
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

# Inside the tree each vouches for, so removing the tree removes the claim
GEM_STAMP="$TOOLCACHE/x64/lib/ruby/gems/.binx_lock_sha"
NPM_STAMP="$REPO/node_modules/.binx_npm_sha"
stamped() { [ "$(cat "$1" 2>/dev/null)" = "$2" ]; }

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

# Over the Ruby's own GEM_HOME, so after the Ruby lands
unpack_gems() {
  local won
  won=$(cat "$BUNDLE_WON" 2>/dev/null)
  [ -n "$won" ] && unpack_ruby_tree "$won" || return 0
  # After a source build the prefix is the real directory $TOOLCACHE/x64 points at
  ruby_is_built || link_ruby_prefix
  if [ "$won" = "$BUNDLE_TARBALL" ]; then
    say "prebuilt gems for Gemfile.lock ${LOCK_SHA} installed"
  else
    say "no bundle for Gemfile.lock ${LOCK_SHA}; unpacked ${won}, bundle install will reconcile"
  fi
}

[ -z "$BUNDLE_DL_PID" ] || { wait "$BUNDLE_DL_PID"; unpack_gems; }
[ -z "$NODE_DL_PID" ] || wait "$NODE_DL_PID"

wait "$SYSTEM_PID" || say "system setup had a problem - see /tmp/system_setup.log"
report_prebuilt

# bin/setup seeds on every run, and a second db:seed dies on duplicates
say "bin/workspace_setup --without_seeds"
bin/workspace_setup --without_seeds || exit 1

# After workspace_setup: .workspace_id gives BASE_URL its port
eval "$(ruby bin/env --export)"

# The pin can want a newer build than /opt/pw-browsers ships; the :js specs launch this one
npx --no-install playwright install chromium-headless-shell >/tmp/playwright_install.log 2>&1 &
PW_PID=$!

# ~95s nothing at session start needs, so detached with every fd redirected — else the
# SessionStart hook waits on it. psql because a Rails boot is ~7s.
SEED_STATUS=/tmp/seed.status
DEV_DB="bikeindex_development_${WORKSPACE_ID}"
SEEDED=$(psql -d "$DEV_DB" -tAc 'SELECT EXISTS (SELECT 1 FROM bikes)' 2>&1)
if [ "$SEEDED" = "f" ]; then
  say "seeding the development database in the background -> /tmp/seed.log"
  say "  wait for it: until grep -qx 'done\|failed' $SEED_STATUS; do sleep 5; done"
  echo running > "$SEED_STATUS"
  # Redirecting around the seed would truncate the status to empty while it runs
  setsid nohup bash -c "if bundle exec rails db:seed; then s=done; else s=failed; fi; echo \$s > $SEED_STATUS" \
    </dev/null >/tmp/seed.log 2>&1 &
elif [ "$SEEDED" = "t" ]; then
  echo done > "$SEED_STATUS"
  say "development database already seeded"
else
  echo failed > "$SEED_STATUS"
  say "couldn't tell whether $DEV_DB is seeded, so didn't seed it: $SEEDED"
fi

if [ "$DEV_SERVER" = 1 ]; then
  say "starting bin/dev -> /tmp/dev_server.log"
  setsid nohup bin/dev </dev/null >/tmp/dev_server.log 2>&1 &
  # Bounded, so a server that dies on boot doesn't hang the hook
  for _ in $(seq 1 48); do curl -fs -o /dev/null "$BASE_URL/" && break; sleep 5; done
  if curl -fs -o /dev/null "$BASE_URL/"; then
    say "dev server up at $BASE_URL"
  else
    say "dev server never answered on $BASE_URL - see /tmp/dev_server.log"
    tail -20 /tmp/dev_server.log
  fi
fi

wait "$PW_PID" || say "playwright browser install failed - see /tmp/playwright_install.log (:js specs need it)"

# Here, not at unpack: bin/setup's installs are what make the trees match their lockfiles
printf '%s' "$LOCK_SHA" > "$GEM_STAMP"
printf '%s' "$NPM_SHA" > "$NPM_STAMP"

# Set by the SessionStart hook; what's written here is exported into the session's shells
if [ -n "${CLAUDE_ENV_FILE:-}" ] && ! grep -qF "$RUBY_PREFIX/bin" "$CLAUDE_ENV_FILE" 2>/dev/null; then
  printf '%s\n' "$ENV_EXPORTS" >> "$CLAUDE_ENV_FILE"
  say "wrote the toolchain env to \$CLAUDE_ENV_FILE"
fi

say "done. Shell env for later commands:"
printf '%s\n' "$ENV_EXPORTS" 'eval "$(ruby bin/env --export)"' | sed 's/^/  /' 
