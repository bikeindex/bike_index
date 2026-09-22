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

REPO=/home/user/bike_index
RUBYVER=$(awk '$1=="ruby"{print $2}' "$REPO/.tool-versions")
RUBY_PREFIX="/opt/ruby-${RUBYVER}/x64"

export PATH="$RUBY_PREFIX/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="$RUBY_PREFIX/lib:${LD_LIBRARY_PATH:-}"
export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
export PGHOST=127.0.0.1 PGUSER=rails PGPASSWORD=password
export LANG=C.UTF-8 LC_ALL=C.UTF-8

say() { echo "==> $*"; }

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

if "$RUBY_PREFIX/bin/ruby" --version 2>/dev/null | grep -q "^ruby ${RUBYVER}"; then
  say "ruby ${RUBYVER} already built"
  RUBY_PID=""
else
  say "building ruby ${RUBYVER} in the background (~6 min on 4 cores) -> /tmp/ruby_build.log"
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
CHROME_BIN="$(ls -d /opt/pw-browsers/chromium-*/chrome-linux 2>/dev/null | sort -V | tail -1)/chrome"
mkdir -p /opt/google/chrome /root/.cache/ms-playwright
printf '#!/bin/bash\nexec "%s" --no-sandbox --disable-dev-shm-usage "$@"\n' "$CHROME_BIN" \
  > /opt/google/chrome/chrome
chmod +x /opt/google/chrome/chrome
[ -s /root/.cache/ms-playwright/mcp-auth.json ] ||
  printf '{"cookies":[],"origins":[]}' > /root/.cache/ms-playwright/mcp-auth.json

# ------------------------------------------------------------ back to ruby
if [ -n "$RUBY_PID" ]; then
  say "waiting on the ruby build"
  wait "$RUBY_PID" || { echo "ruby build FAILED - see /tmp/ruby_build.log"; tail -20 /tmp/ruby_build.log; exit 1; }
  say "ruby $("$RUBY_PREFIX/bin/ruby" -e 'print RUBY_VERSION') built"
fi

cd "$REPO"
gem list -i bundler -v "$(awk '/BUNDLED WITH/{getline; print $1}' Gemfile.lock)" >/dev/null 2>&1 ||
  gem install bundler -v "$(awk '/BUNDLED WITH/{getline; print $1}' Gemfile.lock)" --no-document
say "bundle install"
bundle install --jobs "$(nproc)" || exit 1

eval "$(ruby bin/env --export)"
say "creating + migrating databases (all four: dev/test x primary/analytics)"
bundle exec rails db:create db:migrate || exit 1

if [ "${1:-}" = "--dev-server" ]; then
  say "starting bin/dev -> /tmp/dev_server.log"
  nohup bin/dev > /tmp/dev_server.log 2>&1 &
  until curl -fs -o /dev/null "$BASE_URL/"; do sleep 5; done
  say "dev server up at $BASE_URL"
fi

say "done. Shell env for later commands:"
cat <<EOF
  export PATH="$RUBY_PREFIX/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
  export LD_LIBRARY_PATH="$RUBY_PREFIX/lib:\$LD_LIBRARY_PATH"
  export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
  export PGHOST=127.0.0.1 PGUSER=rails PGPASSWORD=password LANG=C.UTF-8 LC_ALL=C.UTF-8
  eval "\$(ruby bin/env --export)"
EOF
