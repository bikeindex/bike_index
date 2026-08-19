# Review apps

Per-PR review apps deployed with [Kamal](https://kamal-deploy.org/) to a single shared host. Each PR gets its own subdomain (`pr-N.review.bikeindex.org`), Postgres role + databases (primary + analytics), and Sidekiq worker.

Review apps run the **sandbox Rails environment** `RAILS_ENV=sandbox`, a near-duplicate of production (`config/environments/sandbox.rb` imports production.rb)

## How to trigger one

1. Open the [Review App workflow](https://github.com/bikeindex/bike_index/actions/workflows/review-app.yml) in Actions.
2. Click the "Run workflow" button, enter the PR number, choose `deploy`.
3. The run adds the `review-app` label up front; when it finishes, the PR shows a "View deployment" button with the URL.

## Running kamal commands against a review app

`bin/kamal_review` runs **any** kamal command against one review app (so you don't have to export the `REVIEW_APP_*` vars or include `--config-file`). Name the app with `--app` — any of these forms work — and everything else passes through to kamal:

```bash
bin/kamal_review console      --app pr-3594 # Access a rails console
bin/kamal_review app logs -f  --app 3594
bin/kamal_review app details  --app pr-3594.review.bikeindex.org
bin/kamal_review app version  --app https://pr-3594.review.bikeindex.org
```

All four resolve to PR `3594`; with no `--app` it defaults to the persistent sandbox app, and `--app sandbox` names it explicitly ([below](#sandbox-persistent-main-deploy)). (It also drives the `deploy`/`destroy`/`reload_database` lifecycle — see [Deploying locally](#deploying-locally).) It uses `REVIEW_APP_HOST` + `.kamal/secrets`, so the 1Password setup above is a prerequisite. The `shared-db`/`shared-redis` accessories live only in the per-PR config, so accessory commands need an explicit `--app 0` (or any PR) — e.g. reboot Postgres after changing its `shared_preload_libraries`:

```bash
bin/kamal_review accessory reboot db --app 0
```

## Sandbox (persistent `main` deploy)

Alongside the per-PR apps, `main` is continuously deployed to **[sandbox.review.bikeindex.org](https://sandbox.review.bikeindex.org)** — think of it as a review app that never gets a PR number and is never destroyed. It shares `config/deploy.review.yml`: with no `REVIEW_APP_PR_NUMBER` set, the ERB resolves the `sandbox` slug and omits the `accessories:` block (so a sandbox deploy can't touch the shared infra the PR apps depend on). It differs only in using Redis logical DB `0` (the one the PR mod-1023 allocation never hands out).

For `bin/kamal_review`, with no `--app` given it defaults to sandbox - but you can also use `--app sandbox` to target it. That covers every passthrough command, plus `reload_database` — the one lifecycle command sandbox accepts, since it deploys from its own workflow and is never destroyed:

```bash
bin/kamal_review shell        --app sandbox   # bash on sandbox
bin/kamal_review console                      # rails console, also on sandbox
bin/kamal_review reload_database --app sandbox
```

The accessory commands `reload_database` needs (`shared-db`, `shared-redis`) aren't in sandbox's config, so it borrows `pr-0`'s — the same trick as `--app 0` above. From CI, run the **Review App** workflow with `pr_number: sandbox` and `reload_database`; it joins `sandbox-deploy`'s concurrency group, so it can't run mid-deploy.

## What about production?

Production runs on Cloud66. The differences vs production:

- ActionMailer routes through [`letter_opener_web`](https://github.com/fgrehm/letter_opener_web) — the gem is in the `:sandbox` Bundler group, so production never loads it. Inbox at `pr-N.review.bikeindex.org/letter_opener`, stored in `tmp/letter_opener/`, wiped on every deploy.
- Mailer **previews** at `/rails/mailers` (off in production), linked from the admin **Mailers** dropdown.
- The log broadcasts to both stdout (`kamal logs`) and `log/sandbox.log`, so the `read_logged_searches` cron has a file to read.

These make information public, but review apps hold no PII - just seeded data + sandbox integrations.

### The `review-app` label is the deploy gate

The workflow adds the `review-app` label whenever a deploy is attempted — up front, before the build, regardless of outcome. So the **first** deploy must be a manual `workflow_dispatch` (unlabeled PRs are skipped by CI's dispatch step). That run labels the PR as it starts, arming auto-redeploy for the PR's life — so after a failed first deploy you just push a fix and CI re-dispatches.

Once labeled:
- **Push → auto-redeploys**: ci.yml's `dispatch` job dispatches this workflow. (No `pull_request: synchronize` trigger — it would leave a skipped review-app check on every push to every unlabeled PR.)
  - A fork's push fires `on: push` in the fork, not here, so this repo's `dispatch` job never sees it — fork PRs only deploy via manual `workflow_dispatch`.
- **Destroy without closing**: re-run with `destroy` (also removes the label).
- **Reset the data**: re-run with `reload_database` ([below](#reloading-the-database)) — the label is left alone.

Only CI's on-push dispatch and `closed` are wired up, so toggling the label by hand does nothing until the next push.

**Teardown is not gated.** `pull_request: closed` destroys every PR, labeled or not — adding the label is best-effort (`|| true`), so an app can be live with no label on it and would otherwise run forever. Destroy skips the build job and is name-scoped and idempotent, so a PR that never had an app costs one short runner.

The step that isn't idempotent is the redis flush, because mod-1023 allocation can point this PR's logical DB at another PR that's still running. So destroy opens by asking the host which apps are up, and skips the flush when one of them shares the DB. That probe also has to succeed: every other step is `|| true`, so an unreachable host would report a clean teardown and let `post` strip the label and GHCR images off an app that's still serving. A failed probe exits non-zero instead, leaving the PR retryable.

## How a deploy works

Four jobs: `resolve` (PR number + action, and labels on deploy), `op` (calls the shared `kamal-deploy.yml` reusable workflow to build + run the kamal command), `post` (PR-side follow-ups: deployment link, failure-comment cleanup, label removal + GHCR image cleanup on destroy), `report` (failure-only). The reusable workflow's `build` job cancels superseded builds (`cancel-in-progress`) while its `run` job serializes per PR *without* cancellation, since killing kamal mid-deploy can strand the deploy lock. `kamal-deploy.yml` is shared with `sandbox.yml`.

| Trigger | Action | What runs |
|---|---|---|
| `workflow_dispatch` → deploy (operator, or auto-dispatched by ci.yml on push to a labeled PR) | `deploy` | add `review-app` label, build image, deploy |
| `workflow_dispatch` → destroy | `destroy` | tear down, remove label, delete PR images from GHCR |
| `workflow_dispatch` → reload_database (a PR, or `pr_number: sandbox`) | `reload_database` | drop both databases, then create + seed them again ([below](#reloading-the-database)) |
| `pull_request: closed` (any PR) | `destroy` | tear down, remove label, delete PR images from GHCR |

Fork PRs are filtered by `resolve`'s same-repo check (`proceed=false`). On **deploy**:

1. The reusable `build` job builds the Docker image (`Dockerfile`) and pushes it to GHCR as `pr-<N>-<sha>`, labeled `service=bike-index-pr-<N>` (kamal requires that label). Warm builds are fast: docker layers cache in GHCR's `:buildcache`, and sprockets' cache persists via a BuildKit cache mount + buildkit-cache-dance.
2. The `run` job runs `bin/kamal_review deploy --app <pr>` → `kamal deploy --version <tag> --skip-push` (tag from `IMAGE_TAG`). Kamal **pulls** the CI image (no rebuild, which would clone the private `app/services/facebook` submodule) and:
   - Boots the per-PR `-web`, `-worker`, `-cron` containers, mounting the `/rails/storage` (ActiveStorage) and `/rails/public/uploads` (Carrierwave) volumes.
   - First boot: `bin/docker-entrypoint` creates the Postgres **superuser** role `bike_index_pr_<N>` and runs `db:prepare`, creating `bike_index_review_pr_<N>_primary` + `_analytics` and **seeding** them before Puma starts — slow, hence `deploy_timeout: 240`. Redeploys skip seeding and boot fast.
   - Later boots: `db:prepare` runs migrations only.
3. `kamal-proxy` routes `pr-<N>.review.bikeindex.org` to the new container.
4. The `review-app` environment surfaces the URL ("View deployment").

Destroy reverses it: purge the PR's ActiveStorage objects from the shared R2 bucket (while the app's still up — see [storage](#storage-is-shared)), `kamal app remove`, drop both databases + the role, `FLUSHDB` the assigned Redis logical DB (unless a running PR shares it — see [teardown](#the-review-app-label-is-the-deploy-gate)), remove any container `app remove` left behind along with the volumes, and delete every `pr-<N>-<sha>` GHCR image version (best-effort, `packages: write`).

### Reloading the database

`reload_database` resets a running app's data to a freshly seeded state without redeploying — for when seeds change, or a demo leaves the data in a mess. Containers, image, volumes and the Postgres role are untouched; only the two databases are rebuilt, by `bin/kamal_review reload_database --app <pr>` (which also purges the app's R2 objects and flushes its redis DB first — see the comments there for why the order matters). It runs the same `db:prepare` the entrypoint runs at boot, so it's as slow as a first deploy, and the app serves partly-seeded data while it runs.

It's the one action that also takes `--app sandbox` / `pr_number: sandbox` ([above](#sandbox-persistent-main-deploy)). With no PR behind it, the workflow skips everything PR-side — labels, the deployment link, the failure comment — so a sandbox failure shows up only in the run.

**Failures comment on the PR.** These runs are `workflow_dispatch`-triggered, so their check runs never hit the PR's rollup. The `report` job comments the failure (edited in place on repeats); the next successful deploy deletes it.

### Scheduled tasks (cron)

Each app gets a `cron` container (a Kamal [`servers` role](https://kamal-deploy.org/docs/configuration/cron/)) running `config/crontab`. It reuses the app image, runs as `root` (cron needs it), and is torn down on destroy. The `env` prefix copies the container env into the crontab so jobs inherit the per-PR config.

| Schedule | Task |
|---|---|
| `*/1 * * * *` | `bin/run_scheduled_job_runner` — enqueues due `ScheduledJobRunner` work |
| `*/5 * * * *` | `pghero:capture_query_stats` |
| `*/30 * * * *` | `read_logged_searches` (needs `ripgrep`, installed in the image) |

## Files involved

| File | Purpose |
|---|---|
| `Dockerfile`, `.dockerignore` | Production-style image (Thruster + Puma + Sidekiq). Used only by review apps. |
| `bin/docker-entrypoint` | Creates the per-PR Postgres **superuser** role + runs `db:prepare` (schema + seed) on first boot |
| `bin/thrust` | Thruster binstub used by the image's `CMD` |
| `bin/kamal_review` | Run kamal against one review app — `deploy`/`destroy`/`reload_database` lifecycle plus arbitrary passthrough commands (resolves the PR number from any id form, sets `REVIEW_APP_*` + `--config-file`) |
| `config/deploy.review.yml` | Kamal config for both targets — ERB derives `pr-<N>` (with `REVIEW_APP_PR_NUMBER`) or the `sandbox` slug (without); accessories emitted for PR apps only |
| `.github/workflows/sandbox.yml` | Thin caller of `kamal-deploy.yml` for the `main`→sandbox deploy, dispatched on every push to `main` — see [Sandbox](#sandbox-persistent-main-deploy) |
| `.github/workflows/kamal-deploy.yml` | Reusable (`workflow_call`) build + kamal-command workflow shared by review-app and sandbox deploys |
| `config/crontab` | Scheduled rake tasks run by the `cron` server role |
| `.kamal/secrets` | Local secrets — pulls from 1Password and `gh auth token` |
| `.kamal/secrets-ci` | CI secrets — dotenv passthrough for GitHub Actions env vars; the workflow copies this over `.kamal/secrets` before running kamal |
| `.kamal/hooks/post-deploy` | Best-effort Honeybadger deploy notification (`sandbox` env); never fails the deploy — no-ops if `HONEYBADGER_API_KEY` is unset or the gem is absent (e.g. CI) |
| `.github/workflows/review-app.yml` | `resolve` + `op` (calls `kamal-deploy.yml`) + `post` + `report` jobs handling all triggers (see [How a deploy works](#how-a-deploy-works)) |
| `.github/workflows/ci.yml` (`dispatch` job) | Auto-dispatches a deploy on every push to a labeled PR — the auto-redeploy half of the label gate |
| `.kamal/provisioning/` | Ansible playbook for one-time host hardening |
| `app/components/page_block/review_app_banner/` | ViewComponent shown in the layout when `ENV["REVIEW_APP"]` is set |

## Known limits

- **Redis DB allocation is mod-1023.** PRs congruent mod 1023 still share a logical DB — caches + Sidekiq queues mix — but that now takes two live apps ~5 months of PRs apart, and destroy skips its flush when it finds one. Raising it further means bumping `--databases` in the redis accessory `cmd:` and `REDIS_DATABASES` in `bin/kamal_review` in lockstep; the cost is ~3.5MB of baseline RSS per 1000 databases and slower active expiry of TTL'd keys.
- **One eviction pool for every app.** `--maxmemory 512mb --maxmemory-policy allkeys-lru` is instance-wide, so it ignores logical DBs entirely: any app's cache growth can evict any other app's keys, including enqueued Sidekiq jobs, with no error. Widening the modulus doesn't help. Watch `evicted_keys` in `INFO stats`.
- <a id="storage-is-shared"></a>**Storage isn't isolated per app.** CarrierWave (bike photos, most images) writes to the per-PR local `_uploads` volume — isolated, dropped on destroy. ActiveStorage attachments go to the shared R2 dev bucket (`cloudflare_dev` / `bikeindex-dev`), where every app writes to the bucket root with random keys (no prefix). Destroy purges a PR's own blobs — enumerated from its database, deleted by their (globally unique) keys — through the running app before `app remove`, so only that PR's objects go. Best-effort: a PR whose app can't boot at destroy orphans its blobs, and blobs from PRs destroyed before this cleanup existed can only be reclaimed by reconciling live keys against the bucket.
- **One Sidekiq worker per app at concurrency=2.** Enough for demos, not for stress-testing queues.
- **Forks aren't auto-deployed.** A maintainer triggers fork PRs manually via `workflow_dispatch` after reviewing the diff.
- **GHCR accumulates untagged versions.** Each build overwrites `:buildcache`, orphaning the prior manifest; destroyed-PR deletions can leave shared-blob leftovers. GHCR never GCs itself — prune untagged versions if the package grows large.
- **Per-PR Postgres roles are SUPERUSER.** Required to load `db/structure.sql`, which creates *and* `COMMENT`s the superuser-only `pg_stat_statements` extension (`COMMENT ON EXTENSION` needs ownership, no `IF NOT EXISTS`), and to own its tables. Tradeoff: review apps aren't isolated from each other on `shared-db`. Acceptable — that Postgres is sandbox-only, ephemeral, no PII, separate from production. A non-superuser design would load the schema as `postgres` and reassign ownership per role.

## Deploying locally

You normally trigger from the workflow, but can run `bin/kamal_review deploy` locally with kamal installed and SSH access. Secrets come from 1Password via Kamal's adapter:

```bash
# One-time
brew install --cask 1password-cli
op signin                              # creates the `bike-index` account shortname
# (or enable Developer → "Integrate with 1Password CLI" in the desktop app, which
#  authenticates `op` across shells — needed for kamal's adapter to work non-interactively)
gh auth login --scopes write:packages  # KAMAL_REGISTRY_PASSWORD=$(gh auth token)
```

`.kamal/secrets` pulls from the **`Kamal/BikeIndex Review`** item in the `bike-index` account, which needs a field per secret name in the file:

```
POSTGRES_PASSWORD            SECRET_KEY_BASE              SESSION_SECRET
VERIFICATION_SECRET          GOOGLE_MAPS                  GOOGLE_MAPS_STATIC
GOOGLE_GEOCODER              MAPBOX_GEOCODER              MAPBOX_MAPPING
R2_DEV_ENDPOINT              R2_DEV_ACCESS_KEY            R2_DEV_ACCESS_KEY_SECRET
HONEYBADGER_API_KEY          SAML_SP_CERTIFICATE          SAML_SP_PRIVATE_KEY
```

The two `SAML_SP_*` fields hold a **base64-encoded** PEM, not the PEM itself — kamal writes
each secret to the host as one `KEY=value` line, so the newlines have to go. Mint a throwaway
pair (never production's); the task prints the one-line form under "One-line form, for a
deploy environment":

```bash
BASE_URL=https://sandbox.review.bikeindex.org bundle exec rails saml:generate_sp_keypair
```

These are the same values as the `REVIEW_APP_*` GitHub Environment secrets ([Initial host setup step 6](#6-ssh-key--github-config)) — keep them in sync. Then:

```bash
bin/kamal_review deploy --app <pr_number> --version <image_tag>
bin/kamal_review reload_database --app <pr_number>   # drop + reseed, no redeploy
bin/kamal_review reload_database --app sandbox       # same, for the sandbox app
```

`REVIEW_APP_HOST` defaults to `host.review.bikeindex.org`; export it only to target a different host under the `*.review.bikeindex.org` wildcard.

----

## Initial host setup (one time)

Done **once, by hand** — the workflow assumes a provisioned host with shared accessories running.

### 1. Provision a VM
Initially a DigitalOcean droplet in `sfo3` on Ubuntu 24.04, Premium AMD/Intel (NVMe), 2 vCPU / 4 GB.

### 2. DNS
Point a **wildcard** A record at the host:
```
*.review.bikeindex.org   A   <host-ip>
```
This covers both the per-PR hostnames and the SSH deploy target (`REVIEW_APP_HOST`, e.g. `host.review.bikeindex.org`) — any name under the wildcard resolves to the host.

### 3. Run the Ansible provisioning playbook
Hardens the host: Docker, Fail2ban, UFW (22/80/443), NTP, swap, key-only SSH. From `.kamal/provisioning/`:

```bash
cp hosts.ini.example hosts.ini
# edit hosts.ini: replace <host1> with the host IP

ansible-galaxy install -r requirements.yml
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbook.yml
```

See `.kamal/provisioning/README.md` for details.

### 4. Boot kamal-proxy
Global on the host; boot once:

```bash
export REVIEW_APP_PR_NUMBER=0          # dummy, just to satisfy the ERB
export REVIEW_APP_HOST=host.review.bikeindex.org
kamal proxy boot --config-file config/deploy.review.yml
```

**TLS is automatic — no cert to manage.** Each PR's `ssl: true` makes kamal-proxy obtain a per-host Let's Encrypt cert (HTTP-01 over port 80) on first deploy and renew it. No wildcard cert, certbot, or DNS-01 — just the wildcard DNS (step 2) and open port 80. (Let's Encrypt's 50 certs/week/domain is ample.)

### 5. Boot shared accessories
From a local clone with kamal installed (`gem install kamal -v '~> 2.0'`). Secrets read from `.kamal/secrets`, so set up the `Kamal/BikeIndex Review` 1Password item first (see [Deploying locally](#deploying-locally)):

```bash
export REVIEW_APP_PR_NUMBER=0          # dummy, just to satisfy the ERB
export REVIEW_APP_HOST=host.review.bikeindex.org

kamal accessory boot db    --config-file config/deploy.review.yml
kamal accessory boot redis --config-file config/deploy.review.yml
```

Creates the `shared-db` (Postgres 17) and `shared-redis` (Redis 7) containers. Every PR's app connects under a per-PR role + database, created on the fly by `bin/docker-entrypoint`.

### 6. SSH key + GitHub config
- Add a deploy user's SSH public key to the host's `authorized_keys` (on DigitalOcean, attach it at droplet-create time).
- Create a `review-app` GitHub Environment, then add:
- **Variable** `REVIEW_APP_HOST` — SSH deploy target (e.g. `host.review.bikeindex.org`); any name under the wildcard works, it's not a public URL.
- **Secrets:**
  - `REVIEW_APP_SSH_KEY` — the matching private key
  - `REVIEW_APP_POSTGRES_PASSWORD` — same as the 1Password item's `POSTGRES_PASSWORD`
  - `REVIEW_APP_SECRET_KEY_BASE`, `REVIEW_APP_SESSION_SECRET`, `REVIEW_APP_VERIFICATION_SECRET` — review-app values (do NOT reuse production)
  - `REVIEW_APP_GOOGLE_MAPS`, `REVIEW_APP_GOOGLE_MAPS_STATIC`, `REVIEW_APP_GOOGLE_GEOCODER`, `REVIEW_APP_MAPBOX_GEOCODER`, `REVIEW_APP_MAPBOX_MAPPING`
  - `REVIEW_APP_R2_DEV_ENDPOINT`, `REVIEW_APP_R2_DEV_ACCESS_KEY`, `REVIEW_APP_R2_DEV_ACCESS_KEY_SECRET` — creds for the `bikeindex-dev` R2 bucket (`cloudflare_dev` in `config/storage.yml`), shared by all review apps; do NOT reuse the production R2 token.
  - `REVIEW_APP_HONEYBADGER_API_KEY` — optional; the post-deploy hook no-ops if unset

Review apps also load the committed **`.env`** at boot (`dotenv-rails` is in the `:sandbox` group). It supplies dev/sandbox creds for third-party integrations — **Stripe (test-mode)**, Twitter, Twilio, Facebook, Strava, Mailchimp, … — so they don't fall through to empty. **kamal's `env:` wins**: dotenv never overrides a var kamal sets, so it only fills gaps. That's why **Stripe is intentionally absent** from the kamal/1Password/GitHub lists — it comes from `.env`. (Google/Mapbox/R2 stay kamal-managed, so their 1Password values must be real, not placeholders.)
