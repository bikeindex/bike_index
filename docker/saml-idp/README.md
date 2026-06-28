# Local SAML SSO verification with Keycloak

Exercises the full SP-initiated login (`/sso/:org_slug/init` → IdP → `/sso/:org_slug/callback`)
against a real Identity Provider running locally. This is a **manual** check — the automated,
CI-covered version lives in `spec/requests/saml_callback_request_spec.rb`.

The bundled realm ships a SAML client and a test user, so there's no Keycloak console
clicking required:

| | |
|---|---|
| Realm | `bikeindex-test` |
| Test user | `ssouser@ssotest.example` / `password` |
| SP entityID (client id) | `http://localhost:3042/sso/sso-test/metadata` |
| ACS URL | `http://localhost:3042/sso/sso-test/callback` |

> The client URLs hard-code dev port **3042** and org slug **`sso-test`**. If your `$DEV_PORT`
> differs, edit `realm-export.json` (and the org slug below) to match before starting.
>
> Keycloak publishes on host port **8080**. If something else already owns 8080, change the
> published port in `compose.yml` (e.g. `"8085:8080"`) and use that port in steps 3–4.

## 1. Generate a dev SP keypair

The SP signs its AuthnRequests, so it needs a keypair. This is dev-only — never commit it.

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=localhost" \
  -keyout /tmp/sp_key.pem -out /tmp/sp_cert.pem
```

Add both to `.env.local` (dotenv loads it; values may be multi-line PEM in quotes):

```bash
SAML_SP_CERTIFICATE="$(cat /tmp/sp_cert.pem)"
SAML_SP_PRIVATE_KEY="$(cat /tmp/sp_key.pem)"
```

## 2. Start Keycloak

```bash
docker compose -f docker/saml-idp/compose.yml up
```

Admin console (if needed): http://localhost:8080 — `admin` / `admin`.

## 3. Grab the IdP's SAML descriptor

Keycloak mints the realm signing cert on first boot, so read it from the published metadata:

```bash
curl -s http://localhost:8080/realms/bikeindex-test/protocol/saml/descriptor
```

From that XML you need three things for the org config below:
- **idp_entity_id** → `http://localhost:8080/realms/bikeindex-test`
- **idp_sso_target_url** → `http://localhost:8080/realms/bikeindex-test/protocol/saml`
- **idp_cert** → the `<ds:X509Certificate>` value (the signing key)

## 4. Configure a local org (rails console)

```ruby
org = Organization.create!(name: "SSO Test", kind: "school") # slug becomes "sso-test"
org.update!(passwordless_user_domain: "ssotest.example")     # matches the test user's email domain
# enable the features (mirror how the admin UI assigns them)
OrganizationFeature.find_or_create_by!(name: "saml + passwordless",
  feature_slugs: %w[saml_sso passwordless_users], amount_cents: 0)
# ...assign that feature to the org via the admin UI, or set enabled_feature_slugs directly, then:

org.create_organization_saml_configuration!(
  enabled: true,
  idp_entity_id: "http://localhost:8080/realms/bikeindex-test",
  idp_sso_target_url: "http://localhost:8080/realms/bikeindex-test/protocol/saml",
  idp_cert: <<~CERT
    -----BEGIN CERTIFICATE-----
    ...paste the descriptor's X509Certificate here...
    -----END CERTIFICATE-----
  CERT
)
```

> The simplest way to enable the two features is the admin org form
> (`/admin/organizations/sso-test/edit`) — it also renders the SAML config card.

## 5. Log in

Start the app (`bin/dev`), then visit:

```
http://localhost:3042/sso/sso-test/init
```

You're redirected to Keycloak. Sign in as `ssouser@ssotest.example` / `password`. Keycloak
POSTs the signed assertion back to the ACS, the SP validates it, provisions the passwordless
user on first login, links an `SsoIdentity`, and signs you in — landing on the org dashboard.

## Teardown

```bash
docker compose -f docker/saml-idp/compose.yml down
```

Remove the `SAML_SP_*` lines from `.env.local` when you're done.
