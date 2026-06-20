# Review apps

Per-PR review apps deployed with [Kamal](https://kamal-deploy.org/) to a single shared host. Each PR gets its own subdomain (`pr-N.review.bikeindex.org`), Postgres role + databases (primary + analytics), and Sidekiq worker.

Review apps run the **staging Rails environment** `RAILS_ENV=staging`, a near-duplicate of production (`config/environments/staging.rb` imports production.rb)

## How to trigger one

1. Open the [Review App workflow](https://github.com/bikeindex/bike_index/actions/workflows/review-app.yml) in Actions.
2. Click the "Run workflow" button, enter the PR number, choose `deploy`.
3. The run adds the `review-app` label up front; when it finishes, the PR shows a "View deployment" button with the URL.

## Running kamal commands against a review app

`bin/kamal_review` runs **any** kamal command against one review app (so you don't have to export the `REVIEW_APP_*` vars or include `--config-file`). Name the app with `--app` — any of these forms work — and everything else passes through to kamal:

```bash
bin/kamal_review app logs -f                          --app 3594
bin/kamal_review app exec --reuse "bin/rails console" --app pr-3594
bin/kamal_review app details                          --app pr-3594.review.bikeindex.org
bin/kamal_review app version                          --app https://pr-3594.review.bikeindex.org
```

All four resolve to PR `3594`. (It also drives the `deploy`/`destroy` lifecycle — see [Deploying locally](#deploying-locally).) It uses `REVIEW_APP_HOST` + `.kamal/secrets`, so the 1Password setup above is a prerequisite. The shared accessories aren't PR-specific, so any PR number works when operating on them — and with no `--app` given it defaults to PR `0`, so reboot Postgres after changing its `shared_preload_libraries` with just:

```bash
bin/kamal_review accessory reboot db
```

## What about production?

Production runs on Cloud66. The differences vs production:

- ActionMailer routes through [`letter_opener_web`](https://github.com/fgrehm/letter_opener_web) — the gem is in the `:staging` Bundler group, so production never loads it. Inbox at `pr-N.review.bikeindex.org/letter_opener`, stored in `tmp/letter_opener/`, wiped on every deploy.
- Mailer **previews** at `/rails/mailers` (off in production), linked from the admin **Mailers** dropdown.
- The log broadcasts to both stdout (`kamal logs`) and `log/staging.log`, so the `read_logged_searches` cron has a file to read.

These make information public, but review apps hold no PII - just seeded data + sandbox integrations.

### The `review-app` label is the gate

The workflow adds the `review-app` label whenever a deploy is attempted — up front, before the build, regardless of outcome. So the **first** deploy must be a manual `workflow_dispatch` (unlabeled PRs are skipped by CI's dispatch step). That run labels the PR as it starts, arming auto-redeploy for the PR's life — so after a failed first deploy you just push a fix and CI re-dispatches.

Once labeled:
- **Push → auto-redeploys**: ci.yml's `dispatch` job dispatches this workflow. (No `pull_request: synchronize` trigger — it would leave a skipped review-app check on every push to every unlabeled PR.)
  - A fork's push fires `on: push` in the fork, not here, so this repo's `dispatch` job never sees it — fork PRs only deploy via manual `workflow_dispatch`.
- **Close PR → auto-destroys** (`pull_request: closed`), removing the label.
- **Destroy without closing**: re-run with `destroy` (also removes the label).

Only CI's on-push dispatch and `closed` are wired up, so toggling the label by hand does nothing until the next push.

## How a deploy works

Four jobs: `resolve` (PR number + deploy/destroy), `build` (label + build/push image; deploy only), `update` (does the work, branching by step `if:`), `report` (failure-only). `build` is separate so a newer push cancels a stale build (`cancel-in-progress`); `update` handles **both deploy and destroy in one job** (separate jobs would show a skipped check every run) and serializes per PR *without* cancellation, since killing kamal mid-deploy can strand the deploy lock.

| Trigger | Action | What runs |
|---|---|---|
| `workflow_dispatch` → deploy (operator, or auto-dispatched by ci.yml on push to a labeled PR) | `deploy` | add `review-app` label, build image, deploy |
| `workflow_dispatch` → destroy | `destroy` | tear down, remove label, delete PR images from GHCR |
| `pull_request: closed` (labeled) | `destroy` | tear down, remove label, delete PR images from GHCR |

Unlabeled PR closes are filtered by `resolve`'s job-level `if:`; fork PRs by the same-repo check (`proceed=false`). On **deploy**:

1. `build` builds the Docker image (`Dockerfile`) and pushes it to GHCR as `pr-<N>-<sha>`, labeled `service=bike-index-pr-<N>` (kamal requires that label). Warm builds are fast: docker layers cache in GHCR's `:buildcache`, and sprockets' cache persists via a BuildKit cache mount + buildkit-cache-dance.
2. `update` runs `bin/kamal_review deploy --app <pr>` → `kamal deploy --version <tag> --skip-push` (tag from `IMAGE_TAG`). Kamal **pulls** the CI image (no rebuild, which would clone the private `app/services/facebook` submodule) and:
   - Boots the per-PR `-web`, `-worker`, `-cron` containers.
   - First boot: `bin/docker-entrypoint` creates the Postgres **superuser** role `bike_index_pr_<N>` and runs `db:prepare`, creating `bike_index_review_pr_<N>_primary` + `_analytics` and **seeding** them before Puma starts — slow, hence `deploy_timeout: 240`. Redeploys skip seeding and boot fast.
   - Later boots: `db:prepare` runs migrations only.
3. `kamal-proxy` routes `pr-<N>.review.bikeindex.org` to the new container.
4. The `review-app` environment surfaces the URL ("View deployment").

Destroy reverses it: `kamal app remove`, drop both databases + the role, `FLUSHDB` the assigned Redis logical DB, and delete every `pr-<N>-<sha>` GHCR image version (best-effort, `packages: write`).

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
| `bin/kamal_review` | Run kamal against one review app — `deploy`/`destroy` lifecycle plus arbitrary passthrough commands (resolves the PR number from any id form, sets `REVIEW_APP_*` + `--config-file`) |
| `config/deploy.review.yml` | Kamal config, ERB-templated per PR via `REVIEW_APP_PR_NUMBER` |
| `config/crontab` | Scheduled rake tasks run by the `cron` server role |
| `.kamal/secrets` | Local secrets — pulls from 1Password and `gh auth token` |
| `.kamal/secrets-ci` | CI secrets — dotenv passthrough for GitHub Actions env vars; the workflow copies this over `.kamal/secrets` before running kamal |
| `.kamal/hooks/post-deploy` | Best-effort Honeybadger deploy notification (`staging` env); never fails the deploy — no-ops if `HONEYBADGER_API_KEY` is unset or the gem is absent (e.g. CI) |
| `.github/workflows/review-app.yml` | `resolve` + `build` + `update` + `report` jobs handling all triggers (see [How a deploy works](#how-a-deploy-works)) |
| `.github/workflows/ci.yml` (`dispatch` job) | Auto-dispatches a deploy on every push to a labeled PR — the auto-redeploy half of the label gate |
| `provisioning/` | Ansible playbook for one-time host hardening |
| `app/components/page_block/review_app_banner/` | ViewComponent shown in the layout when `ENV["REVIEW_APP"]` is set |

## Known limits

- **Redis DB allocation is mod-31.** PRs congruent mod 31 share a logical DB — caches + Sidekiq queues mix. Mitigation: bump `--databases` in the redis accessory `cmd:` and raise `REDIS_DATABASES` in `bin/kamal_review`.
- **Storage is shared.** All review apps write to the same R2 bucket under a `review-app/` prefix.
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
HONEYBADGER_API_KEY
```

These are the same values as the `REVIEW_APP_*` GitHub Environment secrets ([Initial host setup step 6](#6-ssh-key--github-config)) — keep them in sync. Then:

```bash
bin/kamal_review deploy --app <pr_number> --version <image_tag>
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
Hardens the host: Docker, Fail2ban, UFW (22/80/443), NTP, swap, key-only SSH. From `provisioning/`:

```bash
cp hosts.ini.example hosts.ini
# edit hosts.ini: replace <host1> with the host IP

ansible-galaxy install -r requirements.yml
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbook.yml
```

See `provisioning/README.md` for details.

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

Review apps also load the committed **`.env`** at boot (`dotenv-rails` is in the `:staging` group). It supplies dev/sandbox creds for third-party integrations — **Stripe (test-mode)**, Twitter, Twilio, Facebook, Strava, Mailchimp, … — so they don't fall through to empty. **kamal's `env:` wins**: dotenv never overrides a var kamal sets, so it only fills gaps. That's why **Stripe is intentionally absent** from the kamal/1Password/GitHub lists — it comes from `.env`. (Google/Mapbox/R2 stay kamal-managed, so their 1Password values must be real, not placeholders.)
