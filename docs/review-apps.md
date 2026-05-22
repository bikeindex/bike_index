# Review apps

Per-PR review apps deployed with [Kamal](https://kamal-deploy.org/) to a single shared host. Each PR gets its own primary + analytics Postgres databases, its own Sidekiq worker, and a subdomain like `pr-123.review.bikeindex.org`.

Production runs on Cloud66; this stack is **only** for ephemeral review apps. None of the files in this feature are read by production.

## How to trigger one

1. Open the [Review App workflow](https://github.com/bikeindex/bike_index/actions/workflows/review-app.yml) in Actions.
2. Click "Run workflow", enter the PR number, choose `deploy`.
3. When the workflow finishes, it comments on the PR with the URL and adds the `review-app` label.

After the initial deploy, every push to that PR's branch will automatically redeploy (`pull_request: synchronize`) as long as the `review-app` label is present and the PR is from this repo (forks must be redeployed manually).

Closing the PR auto-destroys the review app and removes the label. To destroy without closing, run the workflow with `destroy`.

## One-time host setup (operator)

The workflow assumes a single host is already provisioned with the Kamal stack and accessories running. This is done **once**, by hand, not by the workflow.

### 1. Provision a VM
- Linux (Ubuntu 24.04 LTS recommended), 4 vCPU / 8 GB RAM as a starting point.
- Open ports 22, 80, 443 from the internet.
- Install Docker (per Kamal's [requirements](https://kamal-deploy.org/docs/installation/)).

### 2. DNS
Point a wildcard A record at the host:
```
*.review.bikeindex.org   A   <host-ip>
```

### 3. Wildcard TLS cert
Place the wildcard cert + key at:
```
/etc/ssl/review.bikeindex.org/fullchain.pem
/etc/ssl/review.bikeindex.org/privkey.pem
```
Set up renewal there (e.g. certbot DNS-01) with a post-renew hook that calls `kamal proxy reboot` so the proxy picks up the new cert.

### 4. SSH key
- Add an SSH public key for the deploy user (e.g. `kamal`) to the host's `authorized_keys`.
- Add the matching **private key** to the GitHub repo as a secret named `REVIEW_APP_SSH_KEY` (in the `review-app` GitHub Environment — see step 7).
- Add the host's address to the repo as a **variable** (not secret) named `REVIEW_APP_HOST`.

### 5. Boot the accessories
From a local clone with `kamal` installed (`gem install kamal -v '~> 2.0'`):
```
export REVIEW_APP_PR_NUMBER=0           # dummy; required by the ERB
export REVIEW_APP_HOST=review.bikeindex.org
export IMAGE_TAG=bootstrap              # dummy
export POSTGRES_PASSWORD=<choose one>

kamal accessory boot postgres --config-file config/deploy.review.yml
kamal accessory boot redis    --config-file config/deploy.review.yml
```

### 6. First-time Kamal setup
The proxy is global per host and gets configured on the first `kamal deploy`. Verify it picks up the wildcard cert paths in `config/deploy.review.yml` — if your installed Kamal version's option names differ from `ssl_certificate_path` / `ssl_certificate_key_path`, adjust the file and re-deploy. (Kamal's exact proxy syntax for custom certs has changed across 2.x point releases.)

### 7. GitHub secrets
Create a `review-app` Environment in the repo settings and add the following.

**Variables:**
- `REVIEW_APP_HOST` — SSH/HTTP address of the host (e.g. `review.bikeindex.org`)

**Secrets:**
- `REVIEW_APP_SSH_KEY` — private key for the deploy user
- `REVIEW_APP_POSTGRES_PASSWORD` — password set in step 5 (used for the shared role + per-app DB connections)
- `REVIEW_APP_SECRET_KEY_BASE`, `REVIEW_APP_SESSION_SECRET`, `REVIEW_APP_VERIFICATION_SECRET` — review-app values (do NOT reuse production)
- `REVIEW_APP_STRIPE_PUBLISHABLE_KEY`, `REVIEW_APP_STRIPE_SECRET_KEY`, `REVIEW_APP_STRIPE_WEBHOOK_SECRET` — Stripe **test mode** keys
- `REVIEW_APP_POSTMARK_API_TOKEN` — Postmark **sandbox** stream token
- `REVIEW_APP_GOOGLE_MAPS`, `REVIEW_APP_GOOGLE_MAPS_STATIC`, `REVIEW_APP_GOOGLE_GEOCODER`, `REVIEW_APP_MAPBOX_GEOCODER`, `REVIEW_APP_MAPBOX_MAPPING` — review-app keys (may be the same as dev)
- `REVIEW_APP_R2_ENDPOINT`, `REVIEW_APP_R2_ACCESS_KEY`, `REVIEW_APP_R2_ACCESS_KEY_SECRET` — R2 creds scoped to a `review-app/` key prefix (separate IAM token from prod)
- `REVIEW_APP_CLOUDFLARE_TOKEN`
- `REVIEW_APP_HONEYBADGER_API_KEY` — optional; can be a dummy if HB isn't wanted for review apps

Other env vars in `.env` that aren't listed here (Twitter, Twilio, Facebook, etc.) intentionally fall through to empty — those integrations are stubbed for review apps.

## Files involved

| File | Purpose |
|---|---|
| `Dockerfile` + `.dockerignore` | Production-style image used only by review apps |
| `config/deploy.review.yml` | Kamal config, ERB-templated per PR via `REVIEW_APP_PR_NUMBER` |
| `bin/review-app` | Deploy / destroy helper (db create-or-drop, kamal deploy/remove, redis flush) |
| `.github/workflows/review-app.yml` | The single workflow that handles all four trigger paths |
| `app/views/shared/_review_app_banner.html.erb` | Banner shown when `ENV["REVIEW_APP"]` is set |

## Known limits

- **Redis DB allocation is mod-31.** Two PRs whose numbers are congruent mod 31 share a Redis logical DB — caches and Sidekiq queues mix. Acceptable for v1; the mitigation is to bump `--databases` in the redis accessory and `REDIS_DATABASES` in `bin/review-app`.
- **Storage is shared.** All review apps write to the same R2 bucket (under a `review-app/` prefix). Uploads work but aren't isolated between apps.
- **No background-job worker scaling.** Each review app runs a single Sidekiq worker with concurrency=2. Enough for demo workflows; not enough to stress-test queue behavior.
- **Forks aren't auto-deployed.** A maintainer must trigger fork PR deploys manually via `workflow_dispatch` after reviewing the diff.
