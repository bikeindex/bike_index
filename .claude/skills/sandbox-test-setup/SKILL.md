---
name: sandbox-test-setup
description: >-
  Bike Index Ruby + RSpec environment setup. Three environments:
  **(A) local macOS Conductor workspace** (`/Users/…/conductor/workspaces/…`) —
  Ruby is installed via mise but Claude Code's shell sometimes
  spawns subprocesses without the mise shim, so bare `ruby`/`bundle`
  falls back to system 2.6 and fails with `Could not find 'bundler'
  (4.0.0.beta2)`. Fix is a PATH prefix, not a reinstall.
  **(B) Conductor cloud sandbox** (`/home/vercel-sandbox/workspace`,
  Amazon Linux 2023) — nothing is preinstalled, so bare `ruby`/`bundle`/
  `bin/lint` fail with `env: 'ruby': No such file or directory`. Egress is
  open (unlike C), so install mise + dnf build deps and let `mise install`
  compile the pinned Ruby (~2 min).
  **(C) Claude Code's Linux web sandbox** (`/home/user/bike_index`) —
  Ruby must be built from GitHub source (~8–10 min, `cache.ruby-lang.org`
  firewalled); also postgres/redis, tailwind build, Chrome-matching
  ChromeDriver, and a local jsdelivr proxy for `:js, type: :system`
  specs. Trigger whenever a session runs RSpec/bundle/`bin/lint`, or
  the user reports `env: 'ruby': No such file or directory` /
  `Bundler::RubyVersionMismatch` /
  `Could not find 'bundler' (4.0.0.beta2)` /
  `command not found: rspec` / `tailwind.css is not present` /
  chromedriver version-mismatch.
---

# Running Ruby + RSpec for Bike Index

Pick the section matching the environment by its path: macOS paths under
`/Users/…/conductor/workspaces/…` use **Local macOS**;
`/home/vercel-sandbox/workspace` on Amazon Linux uses **Conductor cloud
sandbox**; `/home/user/bike_index` uses **Claude Code web sandbox**.

## Local macOS (Conductor workspace)

Ruby 4.0.6 is installed via [mise](https://mise.jdx.dev/), but Claude
Code's shell sometimes spawns subprocesses without the mise shim on
PATH — bare `ruby` then resolves to `/usr/bin/ruby` (2.6) and `bundle`
fails with `Could not find 'bundler' (4.0.0.beta2)`. **The Ruby is
installed; the PATH just isn't right** — don't reinstall, don't edit
the Gemfile.

Check first; only prefix PATH if `ruby -v` doesn't already print 4.0.6
(`mise exec -- ruby`/`bundle` are unreliable in this harness — they
can still resolve to system 2.6, so use the direct prefix):

```bash
ruby -v
# If it's not 4.0.6:
export PATH="/Users/seth/.local/share/mise/installs/ruby/4.0.6/bin:$PATH"
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

## Conductor cloud sandbox (Amazon Linux)

Identify by the path `/home/vercel-sandbox/workspace` on Amazon Linux 2023
(`ID_LIKE=fedora`, `dnf`, user `vercel-sandbox` with passwordless `sudo`).
**Nothing is preinstalled** — no mise, no Ruby, no compiler — so bare
`ruby`/`bundle`/`bin/lint` fail with `env: 'ruby': No such file or directory`.

Unlike the web sandbox (C), egress here is wide open: `cache.ruby-lang.org`,
`rubygems.org`, `registry.npmjs.org`, `cdn.jsdelivr.net`, and `api.github.com`
are all reachable. So take mise's normal build path — **skip the
GitHub-source hand-build and the jsdelivr proxy**; neither is needed here.

### One-time setup (~2–3 min)

```bash
# 1. Compiler + headers (mise/ruby-build compiles Ruby from source).
#    shared-mime-info is required: the mimemagic gem errors at install without it.
sudo dnf install -y gcc gcc-c++ make openssl-devel readline-devel \
  zlib-devel libyaml-devel libffi-devel gdbm-devel ncurses-devel \
  shared-mime-info

# 2. Install mise (not preinstalled)
curl -fsSL https://mise.run | sh          # -> ~/.local/bin/mise

# 3. Build the Ruby + Node pinned in mise.toml. `mise install` reads the file;
#    the Ruby compile is ~2 min because cache.ruby-lang.org is reachable here.
export PATH="$HOME/.local/bin:$PATH"
cd /home/vercel-sandbox/workspace
mise trust --yes
mise install
```

### Each shell

Activate mise so its shims put the pinned Ruby and a matching Bundler on PATH
(Bundler 4.0.x ships as a default gem — no separate `gem install bundler`):

```bash
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)"
ruby --version      # => ruby 4.0.6 ... [x86_64-linux]
bundle install      # ~8s once shared-mime-info is present; vendor/bundle + .bundle are gitignored
```

`bin/lint`, `bundle exec rspec`, etc. then work normally. If a subprocess
drops the mise shim (same harness quirk as Local macOS), prefix the install
dir directly instead of reactivating (match the version in `mise.toml`):

```bash
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.6/bin:$PATH"
```

### Database-backed specs

Postgres and redis aren't preinstalled here either. Install the server packages
from dnf (`dnf search postgresql` / `dnf search redis` for the current version
suffix), start the daemons, then the psql / db:migrate steps in **Services + DB**
below apply unchanged (that section's `service …` / `apt` wording is web-sandbox
specific, but the SQL and Rails commands are the same). Tailwind (below) still
applies to any spec that renders the layout.

## Claude Code web sandbox

`Gemfile` pins the Ruby version (`ruby "4.0.6"` at time of writing —
**read the current pin from the `ruby` line in `Gemfile`**, it moves) and
`Gemfile.lock` pins `BUNDLED WITH 4.0.15`. No prebuilt binary for that
version is reachable (`cache.ruby-lang.org` is 403'd, `ruby/ruby-builder`'s
toolcache tops out at `3.5.0-preview1`), so build from the GitHub source
tag — about 8–10 min on a 4-core sandbox. Don't fall back to 3.x and patch
the Gemfile; Bundler 4.x's resolver behaves differently and you'll waste
time chasing fake regressions. Once `/opt/ruby-<version>/x64/` exists,
`bundle install` works as-is.

You also need **libvips** on the box — the app loads `ruby-vips` at boot,
so without it every Ruby entry point (`db:migrate`, `rspec`, `rails`) dies
with `LoadError: Could not open library 'vips.so.42'`. It's not a build
dep, so install it separately: `apt-get install -y libvips42` (run
`apt-get update` first if a fetch 404s).

## One-shot Ruby build

Set `RUBYVER` to the pin from `Gemfile`. Skip if
`/opt/ruby-$RUBYVER/x64/bin/ruby --version` already prints it. Three
quirks the bash block handles: (1) GitHub's archive-tarball endpoint
(`/archive/refs/tags/*.tar.gz`) **403s through the sandbox proxy** even
though plain `git` over https to github.com works — so clone the tag
shallowly instead of `curl`-ing a tarball; (2) the source tree ships no
pre-generated `configure`, so `autogen.sh` runs first; (3) `make install`
fetches ~30 bundled gems via `BASERUBY`, whose hardcoded CA bundle doesn't
include the sandbox egress-proxy CA — so we pre-stage every bundled gem
with `curl` (which honours `/etc/ssl/certs/ca-certificates.crt`) before
`make install`.

```bash
RUBYVER=$(grep -oE '^ruby "([0-9.]+)"' /home/user/bike_index/Gemfile | grep -oE '[0-9.]+')

# 1. Source — shallow git clone of the tag. The archive tarball URL 403s here;
#    codeload does too. `git clone` over https is what works.
mkdir -p /tmp/ruby-build-src && cd /tmp/ruby-build-src
git clone --depth 1 --branch "v${RUBYVER}" https://github.com/ruby/ruby.git "ruby-${RUBYVER}"
cd "ruby-${RUBYVER}"

# 2. Generate ./configure (the source tree doesn't ship it)
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
"/tmp/ruby-build-src/ruby-${RUBYVER}/configure" \
  --prefix="/opt/ruby-${RUBYVER}/x64" \
  --enable-shared \
  --disable-install-doc \
  --with-openssl-dir=/usr
make -j"$(nproc)"
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt make install

# 5. Match the GitHub-Actions hostedtoolcache layout some shebangs assume
mkdir -p "/opt/hostedtoolcache/Ruby/${RUBYVER}"
[ -e "/opt/hostedtoolcache/Ruby/${RUBYVER}/x64" ] || \
  ln -s "/opt/ruby-${RUBYVER}/x64" "/opt/hostedtoolcache/Ruby/${RUBYVER}/x64"

cd /home/user/bike_index
"/opt/ruby-${RUBYVER}/x64/bin/ruby" --version   # => ruby $RUBYVER ... [x86_64-linux]
```

## Toolchain on PATH

The Playwright Chromium directory has a build number that changes
between sandbox images, so glob it instead of hardcoding. `service`
lives only on `/usr/sbin`.

```bash
CHROME_DIR=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux | sort -V | tail -1)
export PATH="/opt/ruby-4.0.6/x64/bin:$CHROME_DIR:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="/opt/ruby-4.0.6/x64/lib:$LD_LIBRARY_PATH"
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

The importmap pins three modules (jquery, select2, @honeybadger-io/js)
from `cdn.jsdelivr.net` (403'd) — without them, pages render empty.
Everything else is vendored under `vendor/javascript` and served by the
app itself. Fetch these from `registry.npmjs.org` (allowed) and serve
locally over TLS at the same path layout. Versions below mirror
`config/importmap.rb`; bump when that changes.

```bash
mkdir -p /tmp/cdn
for pkg in "jquery@3.6.3" "select2@4.0.8"; do
  name=${pkg%@*}; ver=${pkg#*@}
  rm -rf /tmp/cdn/$name; mkdir -p /tmp/cdn/$name
  curl -sL "https://registry.npmjs.org/${name}/-/${name}-${ver}.tgz" \
    | tar -xz -C /tmp/cdn/$name --strip-components=1
done
mkdir -p /tmp/cdn/honeybadger-io-js
curl -sL "https://registry.npmjs.org/@honeybadger-io/js/-/js-6.12.3.tgz" \
  | tar -xz -C /tmp/cdn/honeybadger-io-js --strip-components=1

# Reproduce the jsdelivr URL layout
mkdir -p /tmp/cdn/serve/npm '/tmp/cdn/serve/npm/@honeybadger-io'
ln -sf /tmp/cdn/jquery /tmp/cdn/serve/npm/jquery@3.6.3
ln -sf /tmp/cdn/select2 /tmp/cdn/serve/npm/select2@4.0.8
ln -sf /tmp/cdn/honeybadger-io-js \
       '/tmp/cdn/serve/npm/@honeybadger-io/js@6.12.3'

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

Assumes the pinned Ruby is already built (paths below use 4.0.6 — swap for
the current pin). Combines the steps above:

```bash
CHROME_DIR=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux | sort -V | tail -1)
export PATH="/opt/ruby-4.0.6/x64/bin:$CHROME_DIR:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="/opt/ruby-4.0.6/x64/lib:$LD_LIBRARY_PATH"
service postgresql start && service redis-server start
apt-get install -y libvips42   # ruby-vips loads at boot; without it every rails/rspec run dies
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

- **Allowed**: github.com (git-over-https clone/fetch), rubygems.org,
  registry.npmjs.org, storage.googleapis.com, files.pythonhosted.org.
- **Blocked**: cache.ruby-lang.org, cdn.jsdelivr.net, most generic CDNs,
  download.ruby-lang.org, api.github.com. Also GitHub's codeload /
  archive-tarball endpoints (`/archive/refs/tags/*.tar.gz`,
  `codeload.github.com`) 403 through the proxy — `git clone` the tag
  instead of downloading a tarball.

If a tool's default download URL is blocked, look for a GitHub or
npm-registry alternative before giving up.
