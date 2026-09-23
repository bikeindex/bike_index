# Claude Code web sandbox

**The `SessionStart` hook (`.claude/hooks/session-start.sh`) has already set this up**:
Ruby, gems, `node_modules`, libvips + ImageMagick, postgres, redis, the CSS builds, the
Playwright browsers, and `$PATH`/`PG*` exported into your shells. Check with `ruby -v`
and `pg_isready` before setting anything up.

The hook runs `assets/web_sandbox_setup.sh`. Re-run it when the hook didn't finish or an
idle container dropped postgres/redis (a `PG::ConnectionBad`) — it's idempotent:

```bash
bash .claude/skills/sandbox-test-setup/assets/web_sandbox_setup.sh              # setup
bash .claude/skills/sandbox-test-setup/assets/web_sandbox_setup.sh --dev-server # + bin/dev
```

Then:

```bash
eval "$(ruby bin/env --export)"
bundle exec rspec spec/models/bike_spec.rb
LOCAL_CHROME_OVERRIDE=1 bundle exec rspec spec/integration/organized/registrations_search_spec.rb
```

## The seed runs in the background

The script seeds an empty development database after setup, detached so the session
doesn't wait ~95s on it. Wait on it before anything that reads development data — a
screenshot, `rails runner`, `$BASE_URL`:

```bash
until grep -qx 'done\|failed' /tmp/seed.status; do sleep 5; done; cat /tmp/seed.status
```

Log in `/tmp/seed.log`; its `Google API error: request denied` lines are the `.env`
geocoder key being referer-restricted, not a failure. An unseeded database doesn't say
so — counters read zero, comboboxes match nothing. Re-seed from scratch with
`DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rails db:reset` (~2 min).

`--without_seeds` is passed to `bin/workspace_setup` because `bin/setup` seeds on every
run, and a second `db:seed` dies on duplicates.

## How the script gets Ruby

Prebuilt Ruby, gem tree and `node_modules` tarballs come from the `web-sandbox-prebuilt`
release (`.github/workflows/web-sandbox-prebuild.yml`). A changed `Gemfile.lock` falls
back to the newest bundle (`bundle-<ver>-latest.txt`) and `bundle install` reconciles;
a `node_modules` miss falls to `npm install`. Stamps skip both on a warm container.

The `prebuilt assets:` block in the output names what resolved; `http 000` means the
host never answered (network policy), not a missing asset. `BINX_PREBUILT_BASE` repoints
the downloads; `BINX_SKIP_PREBUILT=1` forces the source build — `build_ruby()` in the
script, from the cache.ruby-lang.org tarball or a git clone of the tag, ~6 min on 4
cores. Its log looks like it restarts (miniruby, the real build, each ext's
`configure`); it isn't.

**The pin is `.tool-versions`' `ruby` line.** Never fall back to 3.x and patch the
Gemfile — Bundler 4's resolver differs and you'll chase fake regressions.

`Could not open library 'vips.so.42'` or `executable not found: "identify"` (from
`db:seed`) → `apt-get install -y --no-install-recommends libvips42 imagemagick`,
`apt-get update` first if a fetch 404s.

## By hand

The script prints its env block at the end; it's also this:

```bash
export PATH="/opt/ruby-4.0.6/x64/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin"  # service is in /usr/sbin
export LD_LIBRARY_PATH="/opt/ruby-4.0.6/x64/lib:$LD_LIBRARY_PATH"
export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
export PGHOST=127.0.0.1 PGUSER=rails PGPASSWORD=password  # dev DBs don't take database.yml's CI=1 creds
export LANG=C.UTF-8 LC_ALL=C.UTF-8  # else foreman dies reading .env: invalid byte sequence in US-ASCII

service postgresql start; service redis-server start
sudo -u postgres psql -c "CREATE USER rails WITH SUPERUSER PASSWORD 'password';"  # once
bin/workspace_setup --without_seeds   # .workspace_id, bundle, npm, all four databases
eval "$(ruby bin/env --export)"
```

`bin/setup` loads `db/structure.sql`, so a fresh database has every migration in
seconds; stepping through migrations one by one means something half-created it.

## The dev server

Start it yourself — the container is yours (SKILL.md). It never returns, so background
it and poll:

```bash
nohup bin/dev > /tmp/dev_server.log 2>&1 &
until curl -fs -o /dev/null "$BASE_URL/"; do sleep 5; done   # first boot ~40s
```

It runs the tailwind/dartsass watchers and its own redis (which exits harmlessly when
one is already up). It needs no node — the image's 20.x against the 24.x pin doesn't
matter.

**Poll the artifact, never a duration.** A backgrounded command returns exit 0
immediately, and `sleep 300` has come back in well under 300s here.

## Playwright MCP

A different browser from the specs', configured by the script:

- `/opt/google/chrome/chrome` is a **wrapper script** adding `--no-sandbox`, because
  `.mcp.json` launches without it and we're root. A plain symlink dies with `Running as
  root without --no-sandbox is not supported`, which reads like a missing browser.
  Don't add the flag to `.mcp.json` — it's shared with the human's Mac.
- `/root/.cache/ms-playwright/mcp-auth.json` has to exist (`{"cookies":[],"origins":[]}`).
- If the error names a chromium build the image lacks, `npx playwright install chromium`
  and point the wrapper at the new build.

It **can't reach anything off localhost** — it rejects the egress proxy's CA
(`ERR_CERT_AUTHORITY_INVALID`, even with HTTPS errors ignored), so every page logs
failures for jsdelivr, Google Fonts, GTM and Facebook. Those are the sandbox; an
app-origin error is the signal. Screenshots still reach a PR: `github-pr-images` has a
browserless route for here (its `references/web-sandbox.md`).

Selectors: `UI::Forms::Combobox` hides non-matching options rather than removing them,
so use `.hw-combobox__option:not([hidden])`. `browser_click` waits for the page to
settle, so sample sub-second states inside one `browser_evaluate`.

## `:js, type: :system` specs

They run through `capybara-playwright-driver` and the `playwright` npm package — **no
chromedriver, no Selenium**. Needs `LOCAL_CHROME_OVERRIDE=1`: `spec/support/local_chrome.rb`
then adds the root-in-a-container flags and routes `cdn.jsdelivr.net` to `127.0.0.1:8443`.

On a browser-not-found, ask where it's looking:

```bash
npx playwright install --dry-run   # expected install dir + build per browser
npx playwright install chromium-headless-shell   # the build the specs launch, ~10s
```

Where `cdn.playwright.dev` is refused, symlink the image's build under the wanted
number instead (here 1194 → 1223):

```bash
mkdir -p /opt/pw-browsers/chromium_headless_shell-1223
ln -sfn /opt/pw-browsers/chromium_headless_shell-1194/chrome-linux \
        /opt/pw-browsers/chromium_headless_shell-1223/chrome-headless-shell-linux64
ln -sfn headless_shell /opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/chrome-headless-shell
```

### The jsdelivr shim — rarely needed

The only CDN pin in `config/importmap.rb` is `@honeybadger-io/js`, loaded through a
guarded `import()`, so specs pass with nothing on :8443. Only if a spec needs a CDN
module, mirror the pins and serve them. It impersonates a public host over TLS, which
auto mode may refuse — ask rather than work around it:

```bash
for u in $(grep '^pin' config/importmap.rb | grep -o 'https://cdn.jsdelivr.net/[^"]*'); do
  curl -sf --create-dirs -o "/tmp/cdn/serve/${u#https://cdn.jsdelivr.net/}" "$u"; done
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -keyout /tmp/cdn/key.pem -out /tmp/cdn/cert.pem \
  -subj "/CN=cdn.jsdelivr.net" -addext "subjectAltName=DNS:cdn.jsdelivr.net" 2>/dev/null
nohup python3 .claude/skills/sandbox-test-setup/assets/cdn_server.py >/dev/null 2>&1 &
```

## No `gh`

Use the GitHub MCP tools, via the `pr` skill (its appendix maps `gh` to them). The
`pr-guardrails` hook denies `create_pull_request` until that skill is loaded, and
`merge_pull_request` always. A push can open a PR by itself, so check for one first.
`list_pull_requests` reports `merged: false` on merged PRs; `pull_request_read`
(`method: "get"`) is accurate.

## Network

Set by the environment's network policy, so it moves — probe rather than trust this:
`curl -sIL --max-time 5 -o /dev/null -w "%{http_code}\n" https://<host>`.

As of 2026-09-23, **reachable**: github.com (git and release downloads), api.github.com,
raw.githubusercontent.com (`setup:import_spreadsheets`), rubygems.org,
registry.npmjs.org, cache.ruby-lang.org, cdn.playwright.dev, cdn.jsdelivr.net,
api.mapbox.com. **Refused**: download.ruby-lang.org, and GitHub's archive tarballs
(`codeload.github.com`, `/archive/refs/tags/*.tar.gz`) — `git clone` the tag instead.
