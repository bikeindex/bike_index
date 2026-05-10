---
name: sandbox-test-setup
description: >-
  Bike Index sandbox setup for running Ruby specs in Claude Code's web
  sandbox. The Gemfile pins `ruby "4.0.2"` and the lockfile pins
  `BUNDLED WITH 4.0.0.beta2`, so don't fall back to a 3.x ruby — no
  prebuilt 4.0.2 binary is reachable (`cache.ruby-lang.org` is
  firewalled, `ruby/ruby-builder`'s toolcache tops out at 3.5.0-preview1)
  so build it from the GitHub source tag, ~8–10 min on a 4-core sandbox.
  Also covers postgres/redis, the tailwind build, the Chrome-matching
  ChromeDriver, and the local CDN proxy needed for `:js, type: :system`
  specs (jsdelivr is firewalled, registry.npmjs.org isn't). Trigger
  whenever a session needs to run RSpec, the user reports
  `Bundler::RubyVersionMismatch` / `command not found: rspec` /
  `tailwind.css is not present` / chromedriver version-mismatch errors,
  or before attempting any system spec.
---

# Running Ruby + RSpec in the Claude Code sandbox

The bike_index Gemfile pins `ruby "4.0.2"` and `Gemfile.lock` pins
`BUNDLED WITH 4.0.0.beta2`. We actually need Ruby 4.0.2 — don't fall
back to 3.x and patch the Gemfile, because Bundler 4.x's resolver
behaves differently and you'll waste time chasing fake regressions.

The catch: no prebuilt 4.0.2 binary is reachable from the sandbox.
`cache.ruby-lang.org` returns 403 from the egress proxy, and
`ruby/ruby-builder`'s toolcache release currently tops out at
`3.5.0-preview1`. Build it from the GitHub source tag instead — the
build below takes about 8–10 minutes on a 4-core sandbox.

Once `/opt/ruby-4.0.2/x64/` exists, **don't touch the Gemfile**.
`bundle install` works as-is.

## One-shot Ruby 4.0.2 build

Skip if `/opt/ruby-4.0.2/x64/bin/ruby --version` already prints 4.0.2.
GitHub source tarballs lack a pre-generated `configure` script, so we
run `autogen.sh` first. The `make install` step also has to download
about 30 bundled gems via `BASERUBY` — `Downloader::RubyGems` hardcodes
`ssl_ca_cert` to its bundled certs, which don't include the sandbox's
egress-proxy CA, so we pre-stage every bundled gem with `curl` (curl
honours `/etc/ssl/certs/ca-certificates.crt`) before running
`make install`.

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
```

Confirm it works:

```bash
/opt/ruby-4.0.2/x64/bin/ruby --version
# => ruby 4.0.2 ... [x86_64-linux]
```

## Toolchain on PATH

The Playwright Chromium directory has a build number that changes
between sandbox images, so glob it instead of hardcoding:

```bash
CHROME_DIR=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux | sort -V | tail -1)
export PATH="/opt/ruby-4.0.2/x64/bin:$CHROME_DIR:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="/opt/ruby-4.0.2/x64/lib:$LD_LIBRARY_PATH"

bundle install   # no Gemfile edits needed
```

## Services + DB

`service` lives only on `/usr/sbin` — already in the PATH above. Start
postgres and redis once per session:

```bash
service postgresql start    # done
service redis-server start  # done (prints a benign ulimit warning)
```

Create the `rails` superuser and test databases once per machine:

```bash
sudo -u postgres psql -c "CREATE USER rails WITH SUPERUSER PASSWORD 'password';"
sudo -u postgres psql -c "CREATE DATABASE bikeindex_test OWNER rails;"
sudo -u postgres psql -c "CREATE DATABASE bikeindex_analytics_test OWNER rails;"
```

Then prepare the schema (CI=1 makes `database.yml` use the
rails/password creds at 127.0.0.1):

```bash
eval "$(ruby bin/env --export)"
export RAILS_ENV=test CI=1
bundle exec rails db:migrate db:test:prepare
```

## Asset pipeline (Sprockets) — request specs that render the layout

The application layout calls `stylesheet_link_tag 'tailwind'`. Without
`app/assets/builds/tailwind.css`, request specs that hit `format: :html`
fail with `Sprockets::Rails::Helper::AssetNotFound`. **Don't write the
failure off as "pre-existing" — build Tailwind:**

```bash
bundle exec rails tailwindcss:build
```

(See the `integration-testing` skill — same rule applies to
layout-rendering request specs, not just system specs.)

## Running plain specs

```bash
export PATH="/opt/ruby-4.0.2/x64/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="/opt/ruby-4.0.2/x64/lib:$LD_LIBRARY_PATH"
eval "$(ruby bin/env --export)"
export RAILS_ENV=test CI=1

bundle exec rspec spec/models spec/requests spec/jobs
```

## Running `:js, type: :system` specs (integration / component system)

Two extra hurdles in the sandbox:

### 1. Chrome + matching ChromeDriver

- Chrome binary lives at `/opt/pw-browsers/chromium-*/chrome-linux/chrome`
  — the `chromium-NNNN` directory has a Playwright build number that
  changes between sandbox images, so glob it.
- `/opt/node22/bin/chromedriver` is too new (it tracks current stable,
  Chrome here is whatever Playwright bundled). Pull the matching driver
  from Google's CfT bucket — `storage.googleapis.com` is allowed and
  every CfT release publishes its driver under the exact Chrome version
  string:
  ```bash
  CHROME_DIR=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux | sort -V | tail -1)
  CHROME_VER=$("$CHROME_DIR/chrome" --version | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
  curl -sfL "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VER}/linux64/chromedriver-linux64.zip" \
    -o /tmp/chromedriver.zip
  unzip -o -q /tmp/chromedriver.zip -d /tmp
  cp /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver
  ```
  Add `"$CHROME_DIR"` to PATH (already in the export above).
- Capybara's default `:selenium_chrome_headless` doesn't pass
  `--no-sandbox` or a unique `--user-data-dir`, both required when
  running as root inside a container. Drop a temp file in `spec/support/`
  that overrides the driver behind an env flag, so it's only active when
  you opt in:
  ```ruby
  # spec/support/_zz_local_chrome.rb (delete before commit)
  if ENV["LOCAL_CHROME_OVERRIDE"]
    Capybara.register_driver :selenium_chrome_headless do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--headless=new")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-site-isolation-trials")
      options.add_argument("--ignore-certificate-errors")
      options.add_argument("--host-resolver-rules=MAP cdn.jsdelivr.net 127.0.0.1:8443")
      options.add_argument("--user-data-dir=/tmp/chrome-test-#{Process.pid}-#{rand(10_000)}")
      Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
    end
  end
  ```
  The `_zz_` prefix makes `Dir[...].sort` load it last so it overrides
  the Capybara default. **Delete the file before committing.**

### 2. `cdn.jsdelivr.net` is firewalled

bike_index's importmap pins `jquery`, `select2`, `luxon`,
`@bikeindex/time-localizer`, `@floating-ui/dom`, and `@honeybadger-io/js`
from `https://cdn.jsdelivr.net`. Without them, the marketplace search
form never auto-submits and pages render empty. The proxy returns 403
for jsdelivr but allows `registry.npmjs.org`. Fetch the packages from
npm and serve them locally over TLS at the same path layout jsdelivr
uses. Versions below mirror the current `config/importmap.rb` — bump
them when that file changes.

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

## End-to-end: a green spec run from a fresh shell

```bash
# 1. Build Ruby 4.0.2 if missing (see "One-shot Ruby 4.0.2 build" above)
[ -x /opt/ruby-4.0.2/x64/bin/ruby ] || { echo "Build Ruby first"; exit 1; }

# 2. Toolchain
CHROME_DIR=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux | sort -V | tail -1)
export PATH="/opt/ruby-4.0.2/x64/bin:$CHROME_DIR:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="/opt/ruby-4.0.2/x64/lib:$LD_LIBRARY_PATH"

# 3. Services
service postgresql start
service redis-server start

# 4. App env (no Gemfile edits needed)
cd /home/user/bike_index
bundle install
eval "$(ruby bin/env --export)"
export RAILS_ENV=test CI=1
bundle exec rails db:migrate db:test:prepare
bundle exec rails tailwindcss:build  # only if specs render the layout

# 5a. Plain specs
bundle exec rspec spec/models spec/requests spec/jobs

# 5b. System specs — start the CDN proxy first (see section above), then:
LOCAL_CHROME_OVERRIDE=1 bundle exec rspec spec/integration

# 6. Revert any spec/support/* helper you added before committing
rm -f spec/support/_zz_local_chrome.rb
```

## Sandbox network: what's allowed vs. blocked

Quick probe: `curl -sIL --max-time 5 "https://<host>" -o /dev/null -w "%{http_code}\n"`.

- **Allowed**: github.com, codeload.github.com, rubygems.org,
  registry.npmjs.org, storage.googleapis.com, files.pythonhosted.org.
- **Blocked**: cache.ruby-lang.org, cdn.jsdelivr.net, most generic CDNs,
  download.ruby-lang.org, api.github.com.

If a tool's default download URL is blocked, look for a GitHub or
npm-registry alternative before giving up.
