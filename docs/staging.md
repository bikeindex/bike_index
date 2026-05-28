# Staging

A persistent staging environment deployed with [Kamal](https://kamal-deploy.org/), running at https://staging.bikeindex.org. Production runs on Cloud66; none of these files affect production.

Staging copies production: same Dockerfile, same `RAILS_ENV=production`. The only intentional behavioral difference is that `DISABLE_EMAIL_DELIVERY=true` routes ActionMailer through [`letter_opener_web`](https://github.com/fgrehm/letter_opener_web) (see `config/environments/production.rb`). Nothing leaves the box; captured messages are viewable in-app at https://staging.bikeindex.org/letter_opener.

## How to trigger

1. Open the [Staging workflow](https://github.com/bikeindex/bike_index/actions/workflows/staging.yml) in Actions.
2. Click "Run workflow", choose `deploy` (or `destroy`), optionally pick a ref (defaults to `main`).
3. When the workflow finishes the image is live at `https://staging.bikeindex.org`.

## One-time host setup

Same shape as the review-app host setup (see `docs/review-apps.md`); staging can live on its own VM or on the review-app host — its accessories (`staging-db`, `staging-redis`) are named distinctly so there's no collision.

### 1. Provision a VM
Ubuntu 24.04, 4 vCPU / 8 GB RAM as a starting point. Open ports 22, 80, 443.

### 2. DNS
Point an A record at the host:
```
staging.bikeindex.org   A   <host-ip>
```

### 3. TLS cert
Place the cert + key on the host (path of your choice) and boot kamal-proxy with them, or terminate TLS in front of Kamal. Same pattern as review apps.

### 4. Run the Ansible provisioning playbook
The same playbook used for the review-app host applies (see `provisioning/README.md`).

### 5. Boot kamal-proxy
```bash
kamal proxy boot \
  --certificate-path /etc/ssl/staging.bikeindex.org/fullchain.pem \
  --private-key-path /etc/ssl/staging.bikeindex.org/privkey.pem
```

### 6. Boot staging accessories
From a local clone with kamal installed (`gem install kamal -v '~> 2.0'`):

```bash
export STAGING_HOST=staging.bikeindex.org
export IMAGE_TAG=bootstrap             # dummy
export POSTGRES_PASSWORD=<choose one and save in 1Password / your secret store>

kamal accessory boot db    --config-file config/deploy.staging.yml
kamal accessory boot redis --config-file config/deploy.staging.yml
```

These create the `staging-db` (Postgres 17) and `staging-redis` (Redis 7) containers. `bin/docker-entrypoint` creates the `bike_index_staging` role on first deploy.

### 7. SSH key + GitHub config
- Add an SSH public key for a deploy user to the host's `authorized_keys`.
- Create a `staging` GitHub Environment.
- Add this **variable** to the environment:
  - `STAGING_HOST` — host address (e.g. `staging.bikeindex.org`)
- Add these **secrets** to the environment:
  - `STAGING_SSH_KEY` — the matching private key
  - `STAGING_POSTGRES_PASSWORD` — the password from step 6
  - `STAGING_SECRET_KEY_BASE`, `STAGING_SESSION_SECRET`, `STAGING_VERIFICATION_SECRET` — staging values (do NOT reuse production)
  - `STAGING_STRIPE_PUBLISHABLE_KEY`, `STAGING_STRIPE_SECRET_KEY`, `STAGING_STRIPE_WEBHOOK_SECRET` — Stripe **test mode**
  - `STAGING_POSTMARK_API_TOKEN` — Postmark sandbox stream (defense in depth; email is already disabled)
  - `STAGING_GOOGLE_MAPS`, `STAGING_GOOGLE_MAPS_STATIC`, `STAGING_GOOGLE_GEOCODER`, `STAGING_MAPBOX_GEOCODER`, `STAGING_MAPBOX_MAPPING`
  - `STAGING_R2_ENDPOINT`, `STAGING_R2_ACCESS_KEY`, `STAGING_R2_ACCESS_KEY_SECRET` — R2 creds scoped to a `staging/` prefix (separate IAM token from prod)
  - `STAGING_CLOUDFLARE_TOKEN`
  - `STAGING_HONEYBADGER_API_KEY` — optional

## Why email is disabled

Staging seeds and operates on data shapes that mirror production. Sending real email from staging risks contacting real registered owners, organizations, and stolen-bike reporters. Routing delivery through `letter_opener_web` means the entire mailer code path still runs (templates render, jobs enqueue, view assertions hold), but messages land in an in-app inbox at `/letter_opener` instead of shipping.

If you need to inspect what staging *would* have sent, open https://staging.bikeindex.org/letter_opener — gated by `DeveloperRestriction`, same as `/sidekiq` and `/pghero`. The inbox lives at `tmp/letter_opener/` inside the container and is wiped on every Kamal deploy; if you need a message to outlive a redeploy, grab it from the UI before pushing. To deliver real email from staging temporarily, set `DISABLE_EMAIL_DELIVERY=false` in the Kamal config and redeploy — but **never** do this against a production-cloned dataset without scrubbing first.

## Files involved

| File | Purpose |
|---|---|
| `bin/staging` | Deploy / destroy orchestration script |
| `config/deploy.staging.yml` | Kamal config (single-tenant, dedicated accessories) |
| `.github/workflows/staging.yml` | Manual `workflow_dispatch` deploy/destroy |
| `config/environments/production.rb` | Disables ActionMailer delivery when `DISABLE_EMAIL_DELIVERY=true` |
