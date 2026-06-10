# Review apps

Per-PR review apps deployed with [Kamal](https://kamal-deploy.org/) to a single shared host. Each PR gets its own subdomain (`pr-N.review.bikeindex.org`), its own Postgres role + databases (primary + analytics), and its own Sidekiq worker. Production runs on Cloud66; none of these files affect production.

Review apps run the **staging Rails environment** (`RAILS_ENV=staging`), a near-duplicate of production defined in `config/environments/staging.rb` — keep the two in sync when production changes. The intentional divergences from production: ActionMailer routes through [`letter_opener_web`](https://github.com/fgrehm/letter_opener_web) (gem lives in the `:staging` Bundler group, auto-loaded via `Bundler.require(*Rails.groups)` so real production never pulls it in). Captured messages are viewable at `pr-N.review.bikeindex.org/letter_opener` — unrestricted, since review apps run on seeded data + sandbox integrations and contain no PII. The inbox lives at `tmp/letter_opener/` inside the container and is wiped on every Kamal deploy. Staging also enables ActionMailer **previews** (`/rails/mailers`, linked from the admin **Mailers** dropdown alongside the letter_opener inbox), which are off in production — same no-PII rationale. And it broadcasts the log to both stdout (for `kamal logs`) and `log/staging.log` so the `read_logged_searches` cron job has a file to read.

## How to trigger one

1. Open the [Review App workflow](https://github.com/bikeindex/bike_index/actions/workflows/review-app.yml) in Actions.
2. Click "Run workflow", enter the PR number, choose `deploy`.
3. The run adds the `review-app` label up front; when it finishes, the PR shows a "View deployment" button with the URL.

### The `review-app` label is the gate

Auto-deploy on push is gated by the `review-app` label, which the workflow applies **when a deploy is attempted** — up front, before the build — not by hand and not contingent on success. So the first deploy must come from `workflow_dispatch` (step above): a PR with no label is skipped by CI's dispatch step, so there's nothing to bootstrap it but a manual run. That run labels the PR as soon as it starts deploying — **even if the build or deploy then fails** — which arms auto-redeploy for the rest of the PR's life. So after a failed first deploy you just push a fix and CI re-dispatches automatically; no second manual dispatch needed.

Once the label is present:
- **Every push auto-redeploys**: ci.yml's first `lint_and_scan` step sees the label and dispatches this workflow (`gh workflow run`). There's deliberately no `pull_request: synchronize` trigger in review-app.yml — label-gating one at the job level would leave skipped review-app check runs on every push to every unlabeled PR. Fork pushes don't run CI in this repo, so forks never auto-deploy and must be deployed manually via `workflow_dispatch` (a maintainer reviews the diff first).
- **Closing the PR auto-destroys** (`pull_request: closed`) and removes the label.
- To destroy without closing, re-run the workflow with `destroy` — this also removes the label, so pushes stop auto-deploying until you `workflow_dispatch` a `deploy` again.

Because the only wired-up paths are CI's on-push dispatch and `closed`, toggling the label by hand does nothing on its own: removing it disables the *next* push's auto-redeploy, and adding it has no effect until the next push.

## One-time host setup

The workflow assumes a single host is already provisioned with shared accessories running. This is done **once**, by hand, not by the workflow.

### 1. Provision a VM
Ubuntu 24.04, Premium AMD/Intel (NVMe). 2 vCPU / 4 GB is enough to start; bump if you run many concurrent PRs. Open ports 22, 80, 443. (Bike Index runs this as a DigitalOcean droplet in `sfo3`, alongside production.)

### 2. DNS
Point a **wildcard** A record at the host:
```
*.review.bikeindex.org   A   <host-ip>
```
This covers both the per-PR app hostnames (`pr-N.review.bikeindex.org`) and the SSH deploy target (`REVIEW_APP_HOST`, e.g. `host.review.bikeindex.org`) — any name under the wildcard resolves to the host, so no separate record is needed.

### 3. Run the Ansible provisioning playbook
Hardens the host with Docker, Fail2ban, UFW (allows 22/80/443), NTP, swap, and disables password SSH. From `provisioning/`:

```bash
cp hosts.ini.example hosts.ini
# edit hosts.ini: replace <host1> with the host IP

ansible-galaxy install -r requirements.yml
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbook.yml
```

See `provisioning/README.md` for details.

### 4. Boot kamal-proxy
The kamal-proxy is global on the host. Boot it once:

```bash
export REVIEW_APP_PR_NUMBER=0          # dummy, just to satisfy the ERB
export REVIEW_APP_HOST=host.review.bikeindex.org
kamal proxy boot --config-file config/deploy.review.yml
```

**TLS is automatic — there is no cert to manage.** Each PR's proxy config declares `ssl: true`, so kamal-proxy obtains a per-host Let's Encrypt certificate (HTTP-01 challenge over port 80) the first time `pr-N.review.bikeindex.org` is deployed, and renews it itself. No wildcard cert, certbot, or DNS-01 is involved — the wildcard DNS record (step 2) plus the open port 80 are all that's required. (Let's Encrypt's limit of 50 certs/week per registered domain is ample for review apps.)

### 5. Boot shared accessories
From a local clone with kamal installed (`gem install kamal -v '~> 2.0'`). Secrets are read from `.kamal/secrets`, which pulls from 1Password — so set up the `Kamal/BikeIndex Review` item first (see [Local deploys](#local-deploys)):

```bash
export REVIEW_APP_PR_NUMBER=0          # dummy, just to satisfy the ERB
export REVIEW_APP_HOST=host.review.bikeindex.org

kamal accessory boot db    --config-file config/deploy.review.yml
kamal accessory boot redis --config-file config/deploy.review.yml
```

These create the `shared-db` (Postgres 17) and `shared-redis` (Redis 7) containers. Every PR's app connects to them under a per-PR role + database, created on the fly by `bin/docker-entrypoint`.

### 6. SSH key + GitHub config
- Add an SSH public key for a deploy user to the host's `authorized_keys` (on DigitalOcean, attach the key at droplet-create time).
- Create a `review-app` GitHub Environment.
- Add this **variable** to the environment:
  - `REVIEW_APP_HOST` — SSH host address of the shared review-apps droplet (e.g. `host.review.bikeindex.org`). Any name under the `*.review.bikeindex.org` wildcard works; it's only the deploy target, not a public app URL.
- Add these **secrets** to the environment:
  - `REVIEW_APP_SSH_KEY` — the matching private key
  - `REVIEW_APP_POSTGRES_PASSWORD` — same value as the 1Password item's `POSTGRES_PASSWORD`
  - `REVIEW_APP_SECRET_KEY_BASE`, `REVIEW_APP_SESSION_SECRET`, `REVIEW_APP_VERIFICATION_SECRET` — review-app values (do NOT reuse production)
  - `REVIEW_APP_GOOGLE_MAPS`, `REVIEW_APP_GOOGLE_MAPS_STATIC`, `REVIEW_APP_GOOGLE_GEOCODER`, `REVIEW_APP_MAPBOX_GEOCODER`, `REVIEW_APP_MAPBOX_MAPPING`
  - `REVIEW_APP_R2_DEV_ENDPOINT`, `REVIEW_APP_R2_DEV_ACCESS_KEY`, `REVIEW_APP_R2_DEV_ACCESS_KEY_SECRET` — creds for the `bikeindex-dev` R2 bucket (`cloudflare_dev` service in `config/storage.yml`). Staging review apps share this bucket; do NOT reuse the production R2 token.
  - `REVIEW_APP_HONEYBADGER_API_KEY` — optional; the post-deploy hook no-ops if unset

Review apps also load the committed **`.env`** at boot — `dotenv-rails` is in the `:staging` Bundler group (see `Gemfile`), so it runs in the staging environment. `.env` supplies dev/sandbox values for third-party integrations: **Stripe (test-mode)**, plus Twitter, Twilio, Facebook, Strava, Mailchimp, etc. — so those run against sandbox creds rather than falling through to empty. **kamal's `env:` always wins**: dotenv never overrides a var kamal already sets, so the per-app/managed secrets above take precedence and `.env` only fills in what kamal doesn't set. That's why **Stripe is intentionally absent from the kamal/1Password/GitHub lists** — it comes from `.env`. (Google/Mapbox/R2 stay kamal-managed, so their 1Password values must be real, not placeholders, or those integrations break.)

## Local deploys

You normally trigger review apps from the workflow, but you can also run `bin/review-app` locally if you have kamal installed and SSH access to the host. Secrets come from 1Password via Kamal's adapter:

```bash
# One-time
brew install --cask 1password-cli
op signin                              # creates the `bike-index` account shortname
# (or enable Developer → "Integrate with 1Password CLI" in the desktop app, which
#  authenticates `op` across shells — needed for kamal's adapter to work non-interactively)
gh auth login --scopes write:packages  # KAMAL_REGISTRY_PASSWORD=$(gh auth token)
```

`.kamal/secrets` pulls from the **`Kamal/BikeIndex Review`** item in the `bike-index` 1Password account. The item must have a field per secret name referenced in the file:

```
POSTGRES_PASSWORD            SECRET_KEY_BASE              SESSION_SECRET
VERIFICATION_SECRET          GOOGLE_MAPS                  GOOGLE_MAPS_STATIC
GOOGLE_GEOCODER              MAPBOX_GEOCODER              MAPBOX_MAPPING
R2_DEV_ENDPOINT              R2_DEV_ACCESS_KEY            R2_DEV_ACCESS_KEY_SECRET
HONEYBADGER_API_KEY
```

These are the same review-app-scoped values stored as `REVIEW_APP_*` GitHub Environment secrets (see step 6 above) — keep them in sync.

Then:

```bash
export REVIEW_APP_HOST=host.review.bikeindex.org
bin/review-app deploy <pr_number> <image_tag>
```

## How a deploy works

The workflow runs three jobs — `resolve` (works out the PR number and whether to `deploy` or `destroy`), `build` (adds the label, builds + pushes the image; deploys only), then `update` (does the work, branching on the resolved action via step-level `if:`). `build` is its own job so a newer push cancels a superseded build (`cancel-in-progress` concurrency); `update` deliberately handles **both deploy and destroy in one job** — separate jobs would show one running + one skipped check on every run — and serializes per PR *without* cancellation, because killing kamal mid-deploy can leave the deploy lock held on the host. The ways it can be triggered:

| Trigger | Action | what runs |
|---|---|---|
| `workflow_dispatch` → deploy (operator, or auto-dispatched by ci.yml on push to a labeled PR) | `deploy` | add `review-app` label, build image, deploy |
| `workflow_dispatch` → destroy | `destroy` | tear down, remove label, delete PR images from GHCR |
| `pull_request: closed` (labeled) | `destroy` | tear down, remove label, delete PR images from GHCR |

Unlabeled PR closes are filtered out in `resolve`'s job-level `if:`; fork PRs are additionally filtered by the same-repo check (`proceed=false`). On the **deploy** path:

1. The `build` job builds the Docker image (`Dockerfile`) and pushes it to GHCR as `pr-<N>-<sha>`, labeled `service=bike-index-pr-<N>` (kamal requires that label on the deployed image and normally adds it itself when it builds).
2. The `update` job then runs `bin/review-app deploy <pr> <tag>`, which calls `kamal deploy --version <tag> --skip-push` — kamal **pulls** the CI-built image (it does not rebuild, which would clone the repo + the private `app/services/facebook` submodule) and:
   - Boots the per-PR `bike-index-pr-<N>-web`, `-worker`, and `-cron` containers
   - On first boot, `bin/docker-entrypoint` creates the Postgres **superuser** role `bike_index_pr_<N>` and runs `db:prepare`, which creates `bike_index_review_pr_<N>_primary` + `_analytics` and **seeds** them. Seeding (manufacturer-CSV import, sample bikes, …) runs before Puma starts, so first boot is slow — hence `deploy_timeout: 240` in the config; redeploys (databases already exist) skip seeding and boot fast.
   - On subsequent boots, `db:prepare` runs migrations only
3. `kamal-proxy` routes `pr-<N>.review.bikeindex.org` to the new container.
4. The PR's `review-app` environment surfaces the URL ("View deployment"); the `review-app` label was added up front by `build`.

Destroy reverses it: `kamal app remove`, then drops both databases + the role, then `FLUSHDB`s the assigned Redis logical DB. It also deletes every `pr-<N>-<sha>` image version from GHCR (each push built one) so closed PRs don't accumulate images — best-effort, via the `packages: write` token.

### Scheduled tasks (cron)

Each review app gets a `cron` container (a Kamal [`servers` role](https://kamal-deploy.org/docs/configuration/cron/)) that runs `config/crontab` via the standard Linux cron daemon. It reuses the app image, runs as `root` (the daemon needs it; the image's default `rails` user can't run cron), and is torn down with the rest of the app on destroy. The `env` prefix in its command copies the container's env vars into the crontab so jobs inherit the per-PR DB/Redis/secret config. Current jobs:

| Schedule | Task |
|---|---|
| `*/1 * * * *` | `run_scheduler` — enqueues due `ScheduledJobRunner` work |
| `*/5 * * * *` | `pghero:capture_query_stats` |
| `*/30 * * * *` | `read_logged_searches` (needs `ripgrep`, installed in the image) |

## Files involved

| File | Purpose |
|---|---|
| `Dockerfile`, `.dockerignore` | Production-style image (Thruster + Puma + Sidekiq). Used only by review apps. |
| `bin/docker-entrypoint` | Creates the per-PR Postgres **superuser** role + runs `db:prepare` (schema + seed) on first boot |
| `bin/thrust` | Thruster binstub used by the image's `CMD` |
| `bin/review-app` | Deploy / destroy orchestration script |
| `config/deploy.review.yml` | Kamal config, ERB-templated per PR via `REVIEW_APP_PR_NUMBER` |
| `config/crontab` | Scheduled rake tasks run by the `cron` server role |
| `.kamal/secrets` | Local secrets — pulls from 1Password and `gh auth token` |
| `.kamal/secrets-ci` | CI secrets — dotenv passthrough for GitHub Actions env vars; the workflow copies this over `.kamal/secrets` before running kamal |
| `.kamal/hooks/post-deploy` | Best-effort Honeybadger deploy notification (reports the `staging` env); never fails the deploy — no-ops if `HONEYBADGER_API_KEY` is unset or the gem isn't present (e.g. CI) |
| `.github/workflows/review-app.yml` | `resolve` + `build` + `update` jobs handling all triggers (see [How a deploy works](#how-a-deploy-works)) |
| `provisioning/` | Ansible playbook for one-time host hardening |
| `app/components/page_block/review_app_banner/` | ViewComponent rendered in the application layout when `ENV["REVIEW_APP"]` is set |

## Known limits

- **Redis DB allocation is mod-31.** Two PRs whose numbers are congruent mod 31 share a Redis logical DB — caches and Sidekiq queues mix. Acceptable for v1; mitigation if it bites: bump `--databases` in `config/deploy.review.yml`'s redis accessory `cmd:` and raise `REDIS_DATABASES` in `bin/review-app`.
- **Storage is shared.** All review apps write to the same R2 bucket under a `review-app/` prefix.
- **One Sidekiq worker per app at concurrency=2.** Enough for demo workflows; not enough to stress-test queue behavior.
- **Forks aren't auto-deployed.** A maintainer must trigger fork PR deploys manually via `workflow_dispatch` after reviewing the diff.
- **Per-PR Postgres roles are SUPERUSER.** `bin/docker-entrypoint` creates each `bike_index_pr_<N>` role as a superuser. This is required to load production's `db/structure.sql`, which creates *and* `COMMENT`s the superuser-only `pg_stat_statements` extension (`COMMENT ON EXTENSION` needs ownership and has no `IF NOT EXISTS`), and to own its own tables for migrations/seeds. The tradeoff: review apps are **not isolated from each other** on the shared `shared-db` accessory (a superuser role could touch other PRs' databases). Acceptable because that Postgres is sandbox-only, ephemeral, holds no PII, and is entirely separate from production (Cloud66). A non-superuser design would require loading the schema as the `postgres` superuser and reassigning object ownership per role.
