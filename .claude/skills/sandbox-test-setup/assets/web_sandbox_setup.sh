#!/bin/bash
# One-shot setup for the Claude Code web sandbox (/home/user/bike_index).
#
#   bash .claude/skills/sandbox-test-setup/assets/web_sandbox_setup.sh [--dev-server]
#
# Builds the pinned Ruby if it isn't built, and does everything that doesn't
# depend on it (apt, services, postgres role, chrome wrapper) WHILE that runs.
# Idempotent: re-running it after a container idle period just restarts the
# services. Pass --dev-server to also boot bin/dev in the background.
#
# Logs: /tmp/ruby_build.log, /tmp/dev_server.log
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-/home/user/bike_index}"
RUBYVER=$(awk '$1=="ruby"{print $2}' "$REPO/.tool-versions")
LOCK_SHA=$(sha256sum "$REPO/Gemfile.lock" | cut -c1-12)
# rbconfig bakes the prefix in, so the tarball has to land where it was built:
# ruby/setup-ruby's toolcache path. /opt/ruby-<ver>/x64 stays as a symlink to it.
TOOLCACHE="/opt/hostedtoolcache/Ruby/${RUBYVER}"
RUBY_PREFIX="/opt/ruby-${RUBYVER}/x64"
PREBUILT_BASE="${BINX_PREBUILT_BASE:-https://github.com/bikeindex/bike_index/releases/download/web-sandbox-prebuilt}"

export PATH="$RUBY_PREFIX/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="$RUBY_PREFIX/lib:${LD_LIBRARY_PATH:-}"
export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
export PGHOST=127.0.0.1 PGUSER=rails PGPASSWORD=password
export LANG=C.UTF-8 LC_ALL=C.UTF-8

say() { echo "==> $*"; }

# ------------------------------------------------------------ prebuilt assets
# .github/workflows/web-sandbox-prebuild.yml publishes these; every failure here
# is non-fatal, because building from source is always still an option.
fetch_prebuilt() { # <tarball name>
  local tarball="$1" tmp
  tmp=$(mktemp -d)
  curl -sfL --max-time 600 -o "$tmp/$tarball" "$PREBUILT_BASE/$tarball" &&
    curl -sfL --max-time 60 -o "$tmp/$tarball.sha256" "$PREBUILT_BASE/$tarball.sha256" &&
    (cd "$tmp" && sha256sum -c "$tarball.sha256" >/dev/null) &&
    mkdir -p "$TOOLCACHE" &&
    tar -C "$TOOLCACHE" -xzf "$tmp/$tarball" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  # A half-built prefix left by a timed-out session would shadow what we just
  # unpacked, so move it aside rather than letting the rebuild path win.
  [ -L "$RUBY_PREFIX" ] || [ ! -e "$RUBY_PREFIX" ] || mv "$RUBY_PREFIX" "$RUBY_PREFIX.broken.$$"
  mkdir -p "$(dirname "$RUBY_PREFIX")"
  ln -sfn "$TOOLCACHE/x64" "$RUBY_PREFIX"
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
  mkdir -p "/opt/hostedtoolcache/Ruby/${RUBYVER}"
  [ -e "/opt/hostedtoolcache/Ruby/${RUBYVER}/x64" ] || \
    ln -s "$RUBY_PREFIX" "/opt/hostedtoolcache/Ruby/${RUBYVER}/x64"
  "$RUBY_PREFIX/bin/ruby" --version
}

# Keyed on Gemfile.lock, so it misses on a branch that changed it - `bundle
# install` then fills the gaps against whatever this Ruby already has.
GEMS_PREBUILT=false
fetch_prebuilt_gems() {
  [ "$GEMS_PREBUILT" = false ] && [ "${BINX_SKIP_PREBUILT:-}" != "1" ] || return 0
  if fetch_prebuilt "bundle-${RUBYVER}-${LOCK_SHA}-ubuntu24.04-x86_64.tar.gz"; then
    say "prebuilt gems for Gemfile.lock ${LOCK_SHA} installed"
    GEMS_PREBUILT=true
  fi
}

RUBY_PID=""
if ruby_is_built; then
  say "ruby ${RUBYVER} already installed"
  fetch_prebuilt_gems
elif [ "${BINX_SKIP_PREBUILT:-}" != "1" ] &&
  fetch_prebuilt "ruby-${RUBYVER}-ubuntu24.04-x86_64.tar.gz" && ruby_is_built; then
  say "prebuilt ruby ${RUBYVER} installed"
  fetch_prebuilt_gems
else
  say "no prebuilt ruby - building from source in the background (~6 min on 4 cores) -> /tmp/ruby_build.log"
  build_ruby > /tmp/ruby_build.log 2>&1 &
  RUBY_PID=$!
fi

# ------------------------------------------- everything that doesn't need ruby
# ruby-vips loads at boot, so without libvips every rails/rspec run dies
say "installing libvips42"
if ! ldconfig -p | grep -q libvips.so.42; then
  apt-get install -y libvips42 >/tmp/apt_vips.log 2>&1 ||
    { apt-get update >>/tmp/apt_vips.log 2>&1 && apt-get install -y libvips42 >>/tmp/apt_vips.log 2>&1; }
fi

say "starting postgres + redis"   # redis logs a benign ulimit warning
service postgresql start >/dev/null
service redis-server start 2>&1 | grep -v ulimit
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='rails'" | grep -q 1 ||
  sudo -u postgres psql -c "CREATE USER rails WITH SUPERUSER PASSWORD 'password';"

# Playwright MCP's chrome: fixed path, --no-sandbox (we are root), auth file
say "wiring up chrome for playwright MCP"
CHROME_DIR="$(ls -d /opt/pw-browsers/chromium-*/chrome-linux 2>/dev/null | sort -V | tail -1)"
mkdir -p /root/.cache/ms-playwright
if [ -x "$CHROME_DIR/chrome" ]; then
  mkdir -p /opt/google/chrome
  printf '#!/bin/bash\nexec "%s" --no-sandbox --disable-dev-shm-usage "$@"\n' "$CHROME_DIR/chrome" \
    > /opt/google/chrome/chrome
  chmod +x /opt/google/chrome/chrome
else
  say "no chromium under /opt/pw-browsers - MCP screenshots will not work"
fi
[ -s /root/.cache/ms-playwright/mcp-auth.json ] ||
  printf '{"cookies":[],"origins":[]}' > /root/.cache/ms-playwright/mcp-auth.json

# ------------------------------------------------------------ back to ruby
if [ -n "$RUBY_PID" ]; then
  say "waiting on the ruby build"
  wait "$RUBY_PID" || { echo "ruby build FAILED - see /tmp/ruby_build.log"; tail -20 /tmp/ruby_build.log; exit 1; }
  say "ruby $("$RUBY_PREFIX/bin/ruby" -e 'print RUBY_VERSION') built"
  fetch_prebuilt_gems # the gem tarball is usable even when only the Ruby half missed
fi

cd "$REPO"
BUNDLER_VERSION=$(awk '/BUNDLED WITH/{getline; print $1}' Gemfile.lock)
gem list -i bundler -v "$BUNDLER_VERSION" >/dev/null 2>&1 ||
  gem install bundler -v "$BUNDLER_VERSION" --no-document
if [ "$GEMS_PREBUILT" = true ] && bundle check >/dev/null 2>&1; then
  say "gems satisfied by the prebuilt bundle"
else
  say "bundle install"
  bundle install --jobs "$(nproc)" || exit 1
fi

eval "$(ruby bin/env --export)"
say "creating + migrating databases (all four: dev/test x primary/analytics)"
bundle exec rails db:create db:migrate || exit 1

# ~15s, and without them anything rendering the application layout - a request
# spec on an html format, any :js system spec - dies on AssetNotFound. bin/dev's
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
