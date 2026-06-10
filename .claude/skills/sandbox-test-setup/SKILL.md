---
name: sandbox-test-setup
description: >-
  Bike Index Ruby + RSpec environment setup. Two environments:
  **(A) local macOS Conductor workspace** (`/Users/…/conductor/workspaces/…`) —
  Ruby 4.0.2 is installed via mise but Claude Code's shell sometimes
  spawns subprocesses without the mise shim, so bare `ruby`/`bundle`
  falls back to system 2.6 and fails with `Could not find 'bundler'
  (4.0.0.beta2)`. Fix is a PATH prefix, not a reinstall.
  **(B) Claude Code's Linux web sandbox** (`/home/user/bike_index`) —
  Ruby 4.0.2 must be built from source (~8–10 min, `cache.ruby-lang.org`
  firewalled); also postgres/redis, tailwind build, Chrome-matching
  ChromeDriver, and a local jsdelivr proxy for `:js, type: :system`
  specs. Trigger whenever a session runs RSpec/bundle/`bin/lint`, or
  the user reports `Bundler::RubyVersionMismatch` /
  `Could not find 'bundler' (4.0.0.beta2)` /
  `command not found: rspec` / `tailwind.css is not present` /
  chromedriver version-mismatch.
---

# Running Ruby + RSpec for Bike Index

Pick the section matching the environment: macOS paths under
`/Users/…/conductor/workspaces/…` use **Local macOS**; Linux paths
under `/home/user/bike_index` use **Claude Code web sandbox**.

## Local macOS (Conductor workspace)

Ruby 4.0.2 is installed via [mise](https://mise.jdx.dev/), but Claude
Code's shell sometimes spawns subprocesses without the mise shim on
PATH — bare `ruby` then resolves to `/usr/bin/ruby` (2.6) and `bundle`
fails with `Could not find 'bundler' (4.0.0.beta2)`. **The Ruby is
installed; the PATH just isn't right** — don't reinstall, don't edit
the Gemfile.

Check first; only prefix PATH if `ruby -v` doesn't already print 4.0.2
(`mise exec -- ruby`/`bundle` are unreliable in this harness — they
can still resolve to system 2.6, so use the direct prefix):

```bash
ruby -v
# If it's not 4.0.2:
export PATH="/Users/seth/.local/share/mise/installs/ruby/4.0.2/bin:$PATH"
```

Then run specs the normal way:

```bash
bundle exec rspec spec/path/to/file_spec.rb
```

(No need to `eval "$(ruby bin/env --export)"` first — `config/boot.rb` loads
`bin/env` for every Ruby entry point, so `WORKSPACE_ID` / `DEV_PORT` /
`BASE_URL` / `REDIS_URL` are already set inside the process. Only export
them into the shell when the shell itself reads them, e.g. `curl "$BASE_URL/..."`.)

If `rails_helper` aborts complaining about a pending migration, run
`bundle exec rails db:create db:migrate` first
(`ActiveRecord::Migration.maintain_test_schema!`).

Lint with `bin/lint` (same PATH prefix if needed). Postgres, redis,
and the jsdelivr proxy are handled by your local dev environment —
skip the rest of this skill **except** Tailwind build below, which
can still bite a fresh Conductor workspace where `bin/dev` hasn't
run.

## Claude Code web sandbox

The Gemfile pins `ruby "4.0.2"` and `Gemfile.lock` pins
`BUNDLED WITH 4.0.0.beta2`. No prebuilt 4.0.2 binary is reachable
(`cache.ruby-lang.org` is 403'd, `ruby/ruby-builder`'s toolcache tops
out at `3.5.0-preview1`), so build from the GitHub source tag — about
8–10 min on a 4-core sandbox. Don't fall back to 3.x and patch the
Gemfile; Bundler 4.x's resolver behaves differently and you'll waste
time chasing fake regressions. Once `/opt/ruby-4.0.2/x64/` exists,
`bundle install` works as-is.

## One-shot Ruby 4.0.2 build

Skip if `/opt/ruby-4.0.2/x64/bin/ruby --version` already prints 4.0.2.
Two quirks the bash block handles: (1) GitHub source tarballs lack a
pre-generated `configure`, so `autogen.sh` runs first; (2) `make install`
fetches ~30 bundled gems via `BASERUBY`, whose hardcoded CA bundle
doesn't include the sandbox egress-proxy CA — so we pre-stage every
bundled gem with `curl` (which honours
`/etc/ssl/certs/ca-certificates.crt`) before `make install`.

```bash
# 1. Source — GitHub tag tarball (cache.ruby-lang.org is blocked)
mkdir -p /tmp/ruby-build-src && cd /tmp/ruby-build-src
curl -sfL "https://github.com/ruby/ruby/archive/refs/tags/v4.0.2.tar.gz" \
  | tar -xz
cd ruby-4.0.2

# 2. Generate ./configure (GitHub source tarballs don't ship it)
./autogen.sh

# 3. Pre-stage every bundled gem (avoids the rubygems-cert MITM issue)
while read name ver _; do
  case "$name" in ''|'#'*) continue ;; esac
  out="gems/${name}-${ver}.gem"
  [ -s "$out" ] || curl -sfL --max-time 60 -o "$out" \
    "https://rubygems.org/downloads/${name}-${ver}.gem"
done < gems/bundled_gems

# 4. Configure + build + install (BASERUBY = preinstalled /opt/ruby-3.3.6)
mkdir -p /tmp/ruby-build-src/build && cd /tmp/ruby-build-src/build
/tmp/ruby-build-src/ruby-4.0.2/configure \
  --prefix=/opt/ruby-4.0.2/x64 \
  --enable-shared \
  --disable-install-doc \
  --with-openssl-dir=/usr
make -j"$(nproc)"
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt make install

# 5. Match the GitHub-Actions hostedtoolcache layout some shebangs assume
mkdir -p /opt/hostedtoolcache/Ruby/4.0.2
[ -e /opt/hostedtoolcache/Ruby/4.0.2/x64 ] || \
  ln -s /opt/ruby-4.0.2/x64 /opt/hostedtoolcache/Ruby/4.0.2/x64

cd /home/user/bike_index
/opt/ruby-4.0.2/x64/bin/ruby --version   # => ruby 4.0.2 ... [x86_64-linux]
```

## Toolchain on PATH

The Playwright Chromium directory has a build number that changes
between sandbox images, so glob it instead of hardcoding. `service`
lives only on `/usr/sbin`.

```bash
CHROME_DIR=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux | sort -V | tail -1)
export PATH="/opt/ruby-4.0.2/x64/bin:$CHROME_DIR:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="/opt/ruby-4.0.2/x64/lib:$LD_LIBRARY_PATH"
bundle install
```

## Services + DB

Start postgres and redis once per session (redis logs a benign ulimit
warning). Create the `rails` superuser + test DBs once per machine.
`CI=1` makes `database.yml` use the rails/password creds at 127.0.0.1.

```bash
service postgresql start
service redis-server start

# Once per machine:
sudo -u postgres psql -c "CREATE USER rails WITH SUPERUSER PASSWORD 'password';"
sudo -u postgres psql -c "CREATE DATABASE bikeindex_test OWNER rails;"
sudo -u postgres psql -c "CREATE DATABASE bikeindex_analytics_test OWNER rails;"

eval "$(ruby bin/env --export)"
export RAILS_ENV=test CI=1
bundle exec rails db:migrate db:test:prepare
```

## Tailwind build (both environments)

The application layout calls `stylesheet_link_tag 'tailwind'`. Without
`app/assets/builds/tailwind.css`, specs that render the layout (request
specs hitting `format: :html`, or any `:js, type: :system` spec) fail
with `Sprockets::Rails::Helper::AssetNotFound`. This applies to both
the sandbox AND a fresh Conductor workspace where `bin/dev` /
`tailwindcss:build` haven't run yet. **Don't write the failure off as
"pre-existing" — build Tailwind:**

```bash
bundle exec rails tailwindcss:build
```

(See the `integration-testing` skill — same rule applies to
layout-rendering request specs, not just system specs.)

## Running plain specs

After Toolchain + Services + DB above:

```bash
bundle exec rspec spec/models spec/requests spec/jobs
```

## Running `:js, type: :system` specs (integration / component system)

Two extra hurdles in the sandbox:

### 1. Chrome + matching ChromeDriver

- Chrome binary lives at `/opt/pw-browsers/chromium-*/chrome-linux/chrome`
  — the `chromium-NNNN` directory has a Playwright build number that
  changes between sandbox images, so glob it.
- `/opt/node22/bin/chromedriver` is too new (it tracks current stable;
  Chrome here is whatever Playwright bundled). Pull the matching driver
  from Google's CfT bucket — `storage.googleapis.com` is allowed:
  ```bash
  CHROME_DIR=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux | sort -V | tail -1)
  CHROME_VER=$("$CHROME_DIR/chrome" --version | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
  curl -sfL "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VER}/linux64/chromedriver-linux64.zip" \
    -o /tmp/chromedriver.zip
  unzip -o -q /tmp/chromedriver.zip -d /tmp
  cp /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver
  ```
- Capybara's default `:selenium_chrome_headless` doesn't pass
  `--no-sandbox` or a unique `--user-data-dir`, both required when
  Chrome runs as root in a container. `spec/support/local_chrome.rb`
  re-registers the driver with the right flags, gated on
  `LOCAL_CHROME_OVERRIDE=1`. Just set that env var when running system
  specs.

### 2. `cdn.jsdelivr.net` is firewalled

The importmap pins six modules (jquery, select2, luxon,
@bikeindex/time-localizer, @floating-ui/dom, @honeybadger-io/js) from
`cdn.jsdelivr.net` (403'd) — without them, pages render empty. Fetch
from `registry.npmjs.org` (allowed) and serve locally over TLS at the
same path layout. Versions below mirror `config/importmap.rb`; bump
when that changes.

```bash
mkdir -p /tmp/cdn
for pkg in "jquery@3.6.3" "select2@4.0.8" "luxon@3.5.0"; do
  name=${pkg%@*}; ver=${pkg#*@}
  rm -rf /tmp/cdn/$name; mkdir -p /tmp/cdn/$name
  curl -sL "https://registry.npmjs.org/${name}/-/${name}-${ver}.tgz" \
    | tar -xz -C /tmp/cdn/$name --strip-components=1
done
mkdir -p /tmp/cdn/bikeindex-time-localizer /tmp/cdn/floating-ui-dom \
         /tmp/cdn/honeybadger-io-js
curl -sL "https://registry.npmjs.org/@bikeindex/time-localizer/-/time-localizer-0.2.1.tgz" \
  | tar -xz -C /tmp/cdn/bikeindex-time-localizer --strip-components=1
curl -sL "https://registry.npmjs.org/@floating-ui/dom/-/dom-1.7.3.tgz" \
  | tar -xz -C /tmp/cdn/floating-ui-dom --strip-components=1
curl -sL "https://registry.npmjs.org/@honeybadger-io/js/-/js-6.12.3.tgz" \
  | tar -xz -C /tmp/cdn/honeybadger-io-js --strip-components=1

# Reproduce the jsdelivr URL layout
mkdir -p /tmp/cdn/serve/npm \
         '/tmp/cdn/serve/npm/@bikeindex' \
         '/tmp/cdn/serve/npm/@honeybadger-io' \
         '/tmp/cdn/serve/npm/@floating-ui/dom@1.7.3'
ln -sf /tmp/cdn/jquery /tmp/cdn/serve/npm/jquery@3.6.3
ln -sf /tmp/cdn/select2 /tmp/cdn/serve/npm/select2@4.0.8
ln -sf /tmp/cdn/luxon /tmp/cdn/serve/npm/luxon@3.5.0
ln -sf /tmp/cdn/bikeindex-time-localizer \
       '/tmp/cdn/serve/npm/@bikeindex/time-localizer@0.2.1'
ln -sf /tmp/cdn/honeybadger-io-js \
       '/tmp/cdn/serve/npm/@honeybadger-io/js@6.12.3'
cp /tmp/cdn/floating-ui-dom/dist/floating-ui.dom.mjs \
   '/tmp/cdn/serve/npm/@floating-ui/dom@1.7.3/+esm'

# Self-signed cert for *.jsdelivr.net
openssl req -x509 -newkey rsa:2048 -keyout /tmp/cdn/key.pem \
  -out /tmp/cdn/cert.pem -sha256 -days 365 -nodes \
  -subj "/CN=cdn.jsdelivr.net" \
  -addext "subjectAltName=DNS:cdn.jsdelivr.net" 2>/dev/null

# TLS server on :8443 (script lives next to this skill)
python3 .claude/skills/sandbox-test-setup/assets/cdn_server.py &
disown
```

The `--host-resolver-rules` argument (in the override above) routes
`cdn.jsdelivr.net` → this local server, and `--ignore-certificate-errors`
trusts the self-signed cert.

## End-to-end recap

Assumes Ruby 4.0.2 is already built. Combines the steps above:

```bash
CHROME_DIR=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux | sort -V | tail -1)
export PATH="/opt/ruby-4.0.2/x64/bin:$CHROME_DIR:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="/opt/ruby-4.0.2/x64/lib:$LD_LIBRARY_PATH"
service postgresql start && service redis-server start
cd /home/user/bike_index
bundle install
eval "$(ruby bin/env --export)"
export RAILS_ENV=test CI=1
bundle exec rails db:migrate db:test:prepare
bundle exec rails tailwindcss:build           # only if specs render the layout

bundle exec rspec spec/models spec/requests   # plain
LOCAL_CHROME_OVERRIDE=1 bundle exec rspec spec/integration   # system; CDN proxy must be running
```

## Sandbox network: what's allowed vs. blocked

Quick probe: `curl -sIL --max-time 5 "https://<host>" -o /dev/null -w "%{http_code}\n"`.

- **Allowed**: github.com, codeload.github.com, rubygems.org,
  registry.npmjs.org, storage.googleapis.com, files.pythonhosted.org.
- **Blocked**: cache.ruby-lang.org, cdn.jsdelivr.net, most generic CDNs,
  download.ruby-lang.org, api.github.com.

If a tool's default download URL is blocked, look for a GitHub or
npm-registry alternative before giving up.
