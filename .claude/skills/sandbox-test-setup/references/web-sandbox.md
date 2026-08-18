# Claude Code web sandbox

Longest of the three, so here's the order: build Ruby, put the toolchain on
PATH, start postgres/redis and create the databases. Everything after that is
per-task. The Tailwind build in SKILL.md applies here too.

Setup, in order:
[One-shot Ruby build](#one-shot-ruby-build) ·
[Toolchain on PATH](#toolchain-on-path) ·
[Services + DB](#services--db)

Then, as the task needs them:
[Starting the dev server](#starting-the-dev-server) ·
[Driving the app with Playwright MCP](#driving-the-app-with-playwright-mcp) ·
[No `gh` here](#no-gh-here) ·
[Running plain specs](#running-plain-specs) ·
[Running `:js, type: :system` specs](#running-js-type-system-specs-integration--component-system) ·
[End-to-end recap](#end-to-end-recap) ·
[What's allowed vs. blocked](#sandbox-network-whats-allowed-vs-blocked)

`.tool-versions` pins the Ruby version (`ruby 4.0.6` at time of writing —
**read the current pin from its `ruby` line**, it moves; the `Gemfile` has
no `ruby` directive) and
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

Set `RUBYVER` to the pin from `.tool-versions`. Skip if
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
RUBYVER=$(awk '$1=="ruby"{print $2}' /home/user/bike_index/.tool-versions)

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

`service` lives only on `/usr/sbin`. The browser doesn't belong on `PATH` —
Playwright launches it by path, so it wants `PLAYWRIGHT_BROWSERS_PATH`
instead (see the system-spec section).

```bash
export PATH="/opt/ruby-4.0.6/x64/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
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

## Starting the dev server

`CLAUDE.md` says to stop and ask the user to start `bin/dev`. That rule is about
*their* machine, where the server is a process they own and may already have
running. **In the web sandbox there is nobody to ask** — the container is yours,
it's ephemeral, and nothing else is on the port — so start it yourself when a
task needs a running app (screenshots, checking a page actually renders). On the
macOS workspace and the Conductor cloud sandbox the rule stands: a human owns
that machine, so ask.

Two things beyond Toolchain + Services above. Development databases, which the
test setup doesn't create — and which don't take `database.yml`'s `CI=1` branch,
so the credentials have to be passed as `PG*`. And a UTF-8 locale: foreman reads
`.env` in the process's external encoding, and an unset locale makes that
US-ASCII, which dies on the file's non-ASCII bytes with `invalid byte sequence
in US-ASCII`.

```bash
export PGHOST=127.0.0.1 PGUSER=rails PGPASSWORD=password
export LANG=C.UTF-8 LC_ALL=C.UTF-8
eval "$(ruby bin/env --export)"
bundle exec rails db:create db:migrate   # bikeindex_development + its analytics database
bin/dev                                  # run it in the background - it doesn't return
```

Then wait for it rather than assuming — the first boot compiles assets:

```bash
until curl -fs -o /dev/null "$BASE_URL/"; do sleep 5; done
```

`bin/dev` runs foreman, so the tailwind and dartsass watchers come with it and a
page you screenshot is styled. It starts its own redis, which exits harmlessly
when one is already listening. Postgres and redis don't survive a container idle
period: a server answering `PG::ConnectionBad` wants `service postgresql start`
and a restart, not debugging.

A fresh development database is **empty**, and the app doesn't say so — it renders
a combobox with no matches rather than an error. `bundle exec rails db:seed` needs
`setup:import_spreadsheets` (network), so for a single flow seed only what it asks
for, via `rails runner`: the reference data from the relevant `db/seeds/seed_*.rb`
(`seed_bike_associations` covers colors), a `Manufacturer` or two — and then
`Autocomplete::Loader.load_all(%w[Manufacturer])`, without which the manufacturer
combobox stays empty however many rows exist, because it reads Redis rather than
the database.

## Driving the app with Playwright MCP

The MCP server is a different browser from the one `spec/support/local_chrome.rb`
configures, and it comes up unconfigured. Three one-time fixes, each of which fails
with a message that names the missing path:

```bash
# 1. It looks for the `chrome` channel at a fixed path
mkdir -p /opt/google/chrome
ln -sfn "$(ls -d /opt/pw-browsers/chromium-*/chrome-linux | sort -V | tail -1)/chrome" /opt/google/chrome/chrome

# 2. The npm playwright pin wants a newer browser build than the image ships. Point the
#    expected build number at the one that's there (NNNN from the error, MMMM from `ls`)
ln -sfn /opt/pw-browsers/chromium-MMMM /opt/pw-browsers/chromium-NNNN
mkdir -p /opt/pw-browsers/chromium_headless_shell-NNNN
ln -sfn /opt/pw-browsers/chromium_headless_shell-MMMM/chrome-linux \
        /opt/pw-browsers/chromium_headless_shell-NNNN/chrome-headless-shell-linux64
ln -sfn headless_shell /opt/pw-browsers/chromium_headless_shell-MMMM/chrome-linux/chrome-headless-shell

# 3. It reads a storage-state file that doesn't exist yet
mkdir -p /root/.cache/ms-playwright
printf '{"cookies":[],"origins":[]}' > /root/.cache/ms-playwright/mcp-auth.json
```

This browser gets no `--host-resolver-rules`, so the jsdelivr pins (jquery, select2,
honeybadger) fail to load and every page logs `ERR_TUNNEL_CONNECTION_FAILED` for them,
plus Google Fonts / GTM / Facebook. **Those console errors are the sandbox, not the
app** — read past them and treat an app-origin error as the signal.

It also can't reach anything outside localhost: it doesn't trust the egress proxy's CA,
so github.com fails with `ERR_CERT_AUTHORITY_INVALID` (`curl` is fine — it reads
`/etc/ssl/certs`, Chromium reads its own NSS db, and `certutil` isn't installed). Local
pages screenshot fine; `github-pr-images` and anything else driving a remote
site does not work here, and a logged-in GitHub session can't be established headlessly
either.

Two selector notes for driving pages here: a local `UI::Forms::Combobox` keeps all its
options in the DOM and hides the non-matching ones, so `.hw-combobox__option` `.first()`
resolves to a hidden option and the click times out — use
`.hw-combobox__option:not([hidden])` or match by text. And `mcp__playwright__browser_click`
waits for the page to settle before returning, so it can't measure a state that resolves
in under a second or two; sample from inside one `browser_evaluate` instead.

## No `gh` here

The GitHub CLI isn't installed. Anything the `pr` skill (or any other) expresses as
`gh pr …` goes through the GitHub MCP tools instead — `mcp__github__list_pull_requests`
(filter with `head: "<owner>:<branch>"`), `create_pull_request`, `update_pull_request`,
`pull_request_read`. Check for an existing PR before creating one: a push to a branch can
open a PR by itself, so the branch may already have one whose body wants updating rather
than a second PR.

`list_pull_requests` returns `merged: false` on PRs that are merged — the underlying list
endpoint doesn't populate it. Pass `state: "open"` when you want live PRs; when you need a
specific PR's true state, `pull_request_read` with `method: "get"` reports it correctly.

## Running plain specs

After Toolchain + Services + DB above:

```bash
bundle exec rspec spec/models spec/requests spec/jobs
```

## Running `:js, type: :system` specs (integration / component system)

Two extra hurdles in the sandbox:

### 1. A Chromium the Playwright driver can launch

**There is no chromedriver and no Selenium in this repo.** `:js` specs run
through `capybara-playwright-driver` (`spec/support/capybara.rb`), which
drives the `playwright` npm package pinned in `package.json` — so
`bundle install` isn't enough, `npm install` has to have run too, and
anything that reaches for a CfT chromedriver download is solving a problem
this repo doesn't have.

- **Ask it where it's looking rather than guessing.** This downloads nothing
  and works in any environment:
  ```bash
  npx playwright install --dry-run     # per browser: install location + build number
  ```
  It prints the directory the pinned Playwright expects (`…/ms-playwright/chromium-<build>`)
  and the build number that pin wants. Every question below is answered by
  re-running it.
- The image ships builds under `/opt/pw-browsers`, so redirect it there
  instead of the default `~/.cache/ms-playwright`, and re-run the dry-run to
  confirm the location it now reports:
  ```bash
  export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
  ```
- If the build number it wants isn't the one the image ships, symlink — the
  same mismatch the MCP section above resolves that way. Don't reach for
  `npx playwright install chromium` instead: Chromium's only download URL is
  `cdn.playwright.dev` (no fallbacks, unlike firefox/webkit), which is the
  class of CDN this sandbox blocks.
- `spec/support/local_chrome.rb` re-registers the `:playwright` driver with
  the flags Chromium needs as root in a container (`--no-sandbox`,
  `--disable-dev-shm-usage`) plus the jsdelivr host-resolver rule below,
  gated on `LOCAL_CHROME_OVERRIDE=1`. Set that env var when running system
  specs; the default registration in `spec/support/capybara.rb` passes none
  of them.

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
export PATH="/opt/ruby-4.0.6/x64/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"
export LD_LIBRARY_PATH="/opt/ruby-4.0.6/x64/lib:$LD_LIBRARY_PATH"
export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
service postgresql start && service redis-server start
apt-get install -y libvips42   # ruby-vips loads at boot; without it every rails/rspec run dies
cd /home/user/bike_index
bundle install
npm install                    # the :js driver is the playwright npm package, not chromedriver
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
