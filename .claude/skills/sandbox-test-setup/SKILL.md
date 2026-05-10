---
name: sandbox-test-setup
description: >-
  Bike Index sandbox/environment setup for running Ruby specs in Claude
  Code's web sandbox. The Gemfile pins `ruby "4.0.2"` (which doesn't
  exist anywhere downloadable), but Ruby 3.4.6 is preinstalled at
  `/opt/ruby-3.4.6/x64`. This skill walks through getting `bundle exec
  rspec` running end-to-end: PATH/LD_LIBRARY_PATH, the temporary Gemfile
  pin relax, postgres/redis startup, the tailwind build, the matching
  ChromeDriver, and the local CDN proxy needed for `:js, type: :system`
  specs (jsdelivr is firewalled but registry.npmjs.org isn't). Trigger
  whenever a session needs to run RSpec, the user reports
  `Bundler::RubyVersionMismatch` / `command not found: rspec` /
  `tailwind.css is not present` / chromedriver version-mismatch errors,
  or before attempting any system spec.
---

# Running Ruby + RSpec in the Claude Code sandbox

The bike_index Gemfile pins `ruby "4.0.2"`. **Ruby 4.0.2 doesn't exist on
cache.ruby-lang.org or as a `ruby/ruby-builder` toolcache release**, and
`cache.ruby-lang.org` is blocked by the sandbox network proxy. Don't burn
time trying to install it — Ruby 3.4.6 is already extracted at
`/opt/ruby-3.4.6/x64/`. The codebase uses Ruby 3.4-only syntax (`it`
block parameter, etc.) so 3.4.6 runs everything fine.

Always **revert any Gemfile / Gemfile.lock / spec/support changes you
made just to get tests running** before committing.

## One-shot toolchain setup

```bash
# Ruby on PATH + libruby on LD_LIBRARY_PATH
export PATH="/opt/ruby-3.4.6/x64/bin:/opt/pw-browsers/chromium-1194/chrome-linux:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="/opt/ruby-3.4.6/x64/lib:$LD_LIBRARY_PATH"

# Shebangs in the prebuilt tarball point at /opt/hostedtoolcache/Ruby/3.4.6/x64
# (where GitHub Actions extracts it). Symlink so `gem`, `bundle`, etc. work.
mkdir -p /opt/hostedtoolcache/Ruby/3.4.6
[ -e /opt/hostedtoolcache/Ruby/3.4.6/x64 ] || \
  ln -s /opt/ruby-3.4.6/x64 /opt/hostedtoolcache/Ruby/3.4.6/x64

# Relax the Gemfile pin so Bundler stops complaining. LOCAL ONLY — revert before commit.
sed -i 's/^ruby "4\.0\.2"/ruby ">= 3.4"/' Gemfile
bundle install
```

If `/opt/ruby-3.4.6` is missing, fetch it from `ruby/ruby-builder`
(GitHub is reachable):

```bash
mkdir -p /opt/ruby-3.4.6
curl -sL "https://github.com/ruby/ruby-builder/releases/download/toolcache/ruby-3.4.6-ubuntu-24.04.tar.gz" \
  -o /tmp/ruby-3.4.6.tar.gz
tar -xzf /tmp/ruby-3.4.6.tar.gz -C /opt/ruby-3.4.6
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
eval "$(ruby bin/env --export)"
export LD_LIBRARY_PATH="/opt/ruby-3.4.6/x64/lib:$LD_LIBRARY_PATH"
export PATH="/opt/ruby-3.4.6/x64/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export RAILS_ENV=test CI=1

bundle exec rspec spec/models spec/requests spec/jobs
```

## Running `:js, type: :system` specs (integration / component system)

Two extra hurdles in the sandbox:

### 1. Chrome + matching ChromeDriver

- Chrome binary: `/opt/pw-browsers/chromium-1194/chrome-linux/chrome` —
  add that dir to PATH (already in the export above).
- `/opt/node22/bin/chromedriver` is too new (147 vs Chrome 141). Install
  the matching one from Google's CfT bucket (storage.googleapis.com is
  allowed):
  ```bash
  curl -sL "https://storage.googleapis.com/chrome-for-testing-public/141.0.7390.37/linux64/chromedriver-linux64.zip" \
    -o /tmp/chromedriver.zip
  unzip -o -q /tmp/chromedriver.zip -d /tmp
  cp /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver
  ```
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
`@bikeindex/time-localizer`, and `@floating-ui/dom` from
`https://cdn.jsdelivr.net`. Without them, the marketplace search form
never auto-submits and pages render empty. The proxy returns 403 for
jsdelivr but allows `registry.npmjs.org`. Fetch the packages from npm
and serve them locally over TLS at the same path layout jsdelivr uses:

```bash
mkdir -p /tmp/cdn
for pkg in "jquery@3.6.3" "select2@4.0.8" "luxon@3.5.0"; do
  name=${pkg%@*}; ver=${pkg#*@}
  rm -rf /tmp/cdn/$name; mkdir -p /tmp/cdn/$name
  curl -sL "https://registry.npmjs.org/${name}/-/${name}-${ver}.tgz" \
    | tar -xz -C /tmp/cdn/$name --strip-components=1
done
mkdir -p /tmp/cdn/bikeindex-time-localizer /tmp/cdn/floating-ui-dom
curl -sL "https://registry.npmjs.org/@bikeindex/time-localizer/-/time-localizer-0.2.1.tgz" \
  | tar -xz -C /tmp/cdn/bikeindex-time-localizer --strip-components=1
curl -sL "https://registry.npmjs.org/@floating-ui/dom/-/dom-1.7.3.tgz" \
  | tar -xz -C /tmp/cdn/floating-ui-dom --strip-components=1

# Reproduce the jsdelivr URL layout
mkdir -p /tmp/cdn/serve/npm '/tmp/cdn/serve/npm/@bikeindex' \
         '/tmp/cdn/serve/npm/@floating-ui/dom@1.7.3'
ln -sf /tmp/cdn/jquery /tmp/cdn/serve/npm/jquery@3.6.3
ln -sf /tmp/cdn/select2 /tmp/cdn/serve/npm/select2@4.0.8
ln -sf /tmp/cdn/luxon /tmp/cdn/serve/npm/luxon@3.5.0
ln -sf /tmp/cdn/bikeindex-time-localizer \
       '/tmp/cdn/serve/npm/@bikeindex/time-localizer@0.2.1'
cp /tmp/cdn/floating-ui-dom/dist/floating-ui.dom.mjs \
   '/tmp/cdn/serve/npm/@floating-ui/dom@1.7.3/+esm'

# Self-signed cert + tiny TLS server on :8443
openssl req -x509 -newkey rsa:2048 -keyout /tmp/cdn/key.pem \
  -out /tmp/cdn/cert.pem -sha256 -days 365 -nodes \
  -subj "/CN=cdn.jsdelivr.net" \
  -addext "subjectAltName=DNS:cdn.jsdelivr.net" 2>/dev/null

cat > /tmp/cdn/server.py <<'PY'
import http.server, ssl, os
os.chdir('/tmp/cdn/serve')
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*'); super().end_headers()
    def guess_type(self, path):
        if path.endswith(('.mjs', '+esm', '.js')): return 'application/javascript'
        return super().guess_type(path)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain('/tmp/cdn/cert.pem', '/tmp/cdn/key.pem')
httpd = http.server.HTTPServer(('127.0.0.1', 8443), H)
httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
httpd.serve_forever()
PY
python3 /tmp/cdn/server.py &
disown
```

The `--host-resolver-rules` argument (in the override above) routes
`cdn.jsdelivr.net` → this local server, and `--ignore-certificate-errors`
trusts the self-signed cert.

## End-to-end: a green spec run from a fresh shell

```bash
# 1. Toolchain
export PATH="/opt/ruby-3.4.6/x64/bin:/opt/pw-browsers/chromium-1194/chrome-linux:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="/opt/ruby-3.4.6/x64/lib:$LD_LIBRARY_PATH"
mkdir -p /opt/hostedtoolcache/Ruby/3.4.6
[ -e /opt/hostedtoolcache/Ruby/3.4.6/x64 ] || \
  ln -s /opt/ruby-3.4.6/x64 /opt/hostedtoolcache/Ruby/3.4.6/x64

# 2. Services
service postgresql start
service redis-server start

# 3. App env
cd /home/user/bike_index
sed -i 's/^ruby "4\.0\.2"/ruby ">= 3.4"/' Gemfile
bundle install
eval "$(ruby bin/env --export)"
export RAILS_ENV=test CI=1
bundle exec rails db:migrate db:test:prepare
bundle exec rails tailwindcss:build  # only if specs render the layout

# 4a. Plain specs
bundle exec rspec spec/models spec/requests spec/jobs

# 4b. System specs — start the CDN proxy first (see section above), then:
LOCAL_CHROME_OVERRIDE=1 bundle exec rspec spec/integration

# 5. Always revert local-only edits before committing
git checkout HEAD -- Gemfile Gemfile.lock
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
