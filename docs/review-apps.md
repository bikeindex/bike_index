# Review apps

Per-PR review apps deployed with [Kamal](https://kamal-deploy.org/) to a single shared host. Each PR gets its own subdomain (`pr-N.review.bikeindex.org`), its own Postgres role + databases (primary + analytics), and its own Sidekiq worker. Production runs on Cloud66; none of these files affect production.

Review apps run the **staging Rails environment** (`RAILS_ENV=staging`), a near-duplicate of production defined in `config/environments/staging.rb` — keep the two in sync when production changes. The intentional divergence: ActionMailer routes through [`letter_opener_web`](https://github.com/fgrehm/letter_opener_web) (gem lives in the `:staging` Bundler group, auto-loaded via `Bundler.require(*Rails.groups)` so real production never pulls it in). Captured messages are viewable at `pr-N.review.bikeindex.org/letter_opener` — unrestricted, since review apps run on seeded data + sandbox integrations and contain no PII. The inbox lives at `tmp/letter_opener/` inside the container and is wiped on every Kamal deploy.

## How to trigger one

1. Open the [Review App workflow](https://github.com/bikeindex/bike_index/actions/workflows/review-app.yml) in Actions.
2. Click "Run workflow", enter the PR number, choose `deploy`.
3. When the workflow finishes, it comments on the PR with the URL and adds the `review-app` label.

### The `review-app` label is the gate

Auto-deploy on push is gated by the `review-app` label, and the label is applied **by a successful deploy** — not by hand. So the first deploy must come from `workflow_dispatch` (step above): a PR with no label is skipped by the `pull_request: synchronize` trigger, so there's nothing to bootstrap it but a manual run. That deploy step adds the label, which then arms auto-redeploy for the rest of the PR's life.

Once the label is present:
- **Every push auto-redeploys** (`pull_request: synchronize`), as long as the PR is from this repo — forks are skipped and must be redeployed manually via `workflow_dispatch` (a maintainer reviews the diff first).
- **Closing the PR auto-destroys** (`pull_request: closed`) and removes the label.
- To destroy without closing, re-run the workflow with `destroy` — this also removes the label, so pushes stop auto-deploying until you `workflow_dispatch` a `deploy` again.

Because only `synchronize` and `closed` are wired up, toggling the label by hand does nothing on its own: removing it disables the *next* push's auto-redeploy, and adding it has no effect until the next push.

## One-time host setup

The workflow assumes a single host is already provisioned with shared accessories running. This is done **once**, by hand, not by the workflow.

### 1. Provision a VM
Ubuntu 24.04, 4 vCPU / 8 GB RAM as a starting point. Open ports 22, 80, 443.

### 2. DNS
Point a wildcard A record at the host:
```
*.review.bikeindex.org   A   <host-ip>
```

### 3. Wildcard TLS cert
Place the wildcard cert + key on the host (path of your choice, e.g.):
```
/etc/ssl/review.bikeindex.org/fullchain.pem
/etc/ssl/review.bikeindex.org/privkey.pem
```
Set up renewal there with a post-renew hook that runs `kamal proxy reboot` (so the proxy reloads the new cert files).

### 4. Run the Ansible provisioning playbook
Hardens the host with Docker, Fail2ban, UFW (allows 22/80/443), NTP, swap, and disables password SSH. From `provisioning/`:

```bash
cp hosts.ini.example hosts.ini
# edit hosts.ini: replace <host1> with the host IP

ansible-galaxy install -r requirements.yml
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbook.yml
```

See `provisioning/README.md` for details.

### 5. Boot kamal-proxy with the wildcard cert
The kamal-proxy is global on the host. Boot it once with the wildcard cert paths:

```bash
kamal proxy boot \
  --certificate-path /etc/ssl/review.bikeindex.org/fullchain.pem \
  --private-key-path /etc/ssl/review.bikeindex.org/privkey.pem
```

After this, every PR's app can simply declare `ssl: true` in its proxy config — the proxy serves the wildcard for any `pr-N.review.bikeindex.org`.

### 6. Boot shared accessories
From a local clone with kamal installed (`gem install kamal -v '~> 2.0'`):

```bash
export REVIEW_APP_PR_NUMBER=0          # dummy value just to satisfy the ERB
export REVIEW_APP_HOST=review.bikeindex.org
export IMAGE_TAG=bootstrap             # dummy
export POSTGRES_PASSWORD=<choose one and save in 1Password / your secret store>

kamal accessory boot db    --config-file config/deploy.review.yml
kamal accessory boot redis --config-file config/deploy.review.yml
```

These create the `shared-db` (Postgres 17) and `shared-redis` (Redis 7) containers. Every PR's app connects to them under a per-PR role + database, created on the fly by `bin/docker-entrypoint`.

### 7. SSH key + GitHub config
- Add an SSH public key for a deploy user to the host's `authorized_keys`.
- Create a `review-app` GitHub Environment.
- Add this **variable** to the environment:
  - `REVIEW_APP_HOST` — host address (e.g. `review.bikeindex.org`)
- Add these **secrets** to the environment:
  - `REVIEW_APP_SSH_KEY` — the matching private key
  - `REVIEW_APP_POSTGRES_PASSWORD` — the password from step 6
  - `REVIEW_APP_SECRET_KEY_BASE`, `REVIEW_APP_SESSION_SECRET`, `REVIEW_APP_VERIFICATION_SECRET` — review-app values (do NOT reuse production)
  - `REVIEW_APP_STRIPE_PUBLISHABLE_KEY`, `REVIEW_APP_STRIPE_SECRET_KEY`, `REVIEW_APP_STRIPE_WEBHOOK_SECRET` — Stripe **test mode**
  - `REVIEW_APP_GOOGLE_MAPS`, `REVIEW_APP_GOOGLE_MAPS_STATIC`, `REVIEW_APP_GOOGLE_GEOCODER`, `REVIEW_APP_MAPBOX_GEOCODER`, `REVIEW_APP_MAPBOX_MAPPING`
  - `REVIEW_APP_R2_DEV_ENDPOINT`, `REVIEW_APP_R2_DEV_ACCESS_KEY`, `REVIEW_APP_R2_DEV_ACCESS_KEY_SECRET` — creds for the `bikeindex-dev` R2 bucket (`cloudflare_dev` service in `config/storage.yml`). Staging review apps share this bucket; do NOT reuse the production R2 token.
  - `REVIEW_APP_HONEYBADGER_API_KEY` — optional; the post-deploy hook no-ops if unset

Other Bike Index env vars (Twitter, Twilio, Facebook, etc.) intentionally fall through to empty for review apps; those integrations stay stubbed.

## Local deploys

You normally trigger review apps from the workflow, but you can also run `bin/review-app` locally if you have kamal installed and SSH access to the host. Secrets come from 1Password via Kamal's adapter:

```bash
# One-time
brew install --cask 1password-cli
op signin                              # creates the `bike-index` account shortname
gh auth login --scopes write:packages  # KAMAL_REGISTRY_PASSWORD=$(gh auth token)
```

`.kamal/secrets` pulls from the **`Kamal/BikeIndex Review`** item in the `bike-index` 1Password account. The item must have a field per secret name referenced in the file:

```
POSTGRES_PASSWORD            SECRET_KEY_BASE              SESSION_SECRET
VERIFICATION_SECRET          STRIPE_PUBLISHABLE_KEY       STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET        GOOGLE_MAPS                  GOOGLE_MAPS_STATIC
GOOGLE_GEOCODER              MAPBOX_GEOCODER              MAPBOX_MAPPING
R2_DEV_ENDPOINT              R2_DEV_ACCESS_KEY            R2_DEV_ACCESS_KEY_SECRET
HONEYBADGER_API_KEY
```

These are the same review-app-scoped values stored as `REVIEW_APP_*` GitHub Environment secrets (see step 7 above) — keep them in sync.

Then:

```bash
export REVIEW_APP_HOST=review.bikeindex.org
bin/review-app deploy <pr_number> <image_tag>
```

## How a deploy works

The workflow has two jobs: `resolve` (figures out the PR number + whether the trigger should `deploy` or `destroy`) and `update` (does the work, branching on that decision via step-level `if:`). The build/push steps only run on the deploy path.

1. The `update` job builds the Docker image (`Dockerfile`) and pushes to GHCR as `pr-<N>-<sha>`.
2. It then runs `bin/review-app deploy <pr> <tag>`, which SSHes to the host via Kamal and:
   - Boots the per-PR `bike-index-pr-<N>-web` + `bike-index-pr-<N>-worker` containers
   - On first boot, `bin/docker-entrypoint` creates the Postgres role `bike_index_pr_<N>` and runs `db:prepare`, which creates both `bike_index_review_pr_<N>_primary` and `bike_index_review_pr_<N>_analytics` and seeds them
   - On subsequent boots, `db:prepare` runs migrations only
3. `kamal-proxy` routes `pr-<N>.review.bikeindex.org` to the new container.
4. Workflow adds the `review-app` label and comments the URL on the PR.

Destroy reverses it: `kamal app remove`, then drops both databases + the role, then `FLUSHDB`s the assigned Redis logical DB.

## Files involved

| File | Purpose |
|---|---|
| `Dockerfile`, `.dockerignore` | Production-style image (Thruster + Puma + Sidekiq). Used only by review apps. |
| `bin/docker-entrypoint` | Creates per-PR Postgres role + runs `db:prepare` on first boot |
| `bin/thrust` | Thruster binstub used by the image's `CMD` |
| `bin/review-app` | Deploy / destroy orchestration script |
| `config/deploy.review.yml` | Kamal config, ERB-templated per PR via `REVIEW_APP_PR_NUMBER` |
| `.kamal/secrets` | Local secrets — pulls from 1Password and `gh auth token` |
| `.kamal/secrets-ci` | CI secrets — dotenv passthrough for GitHub Actions env vars; the workflow copies this over `.kamal/secrets` before running kamal |
| `.kamal/hooks/post-deploy` | Honeybadger deploy notification (no-op if `HONEYBADGER_API_KEY` unset) |
| `.github/workflows/review-app.yml` | The single workflow handling all four trigger paths |
| `provisioning/` | Ansible playbook for one-time host hardening |
| `app/components/review_app_banner/` | ViewComponent rendered in the application layout when `ENV["REVIEW_APP"]` is set |

## Known limits

- **Redis DB allocation is mod-31.** Two PRs whose numbers are congruent mod 31 share a Redis logical DB — caches and Sidekiq queues mix. Acceptable for v1; mitigation if it bites: bump `--databases` in `config/deploy.review.yml`'s redis accessory `cmd:` and raise `REDIS_DATABASES` in `bin/review-app`.
- **Storage is shared.** All review apps write to the same R2 bucket under a `review-app/` prefix.
- **One Sidekiq worker per app at concurrency=2.** Enough for demo workflows; not enough to stress-test queue behavior.
- **Forks aren't auto-deployed.** A maintainer must trigger fork PR deploys manually via `workflow_dispatch` after reviewing the diff.
