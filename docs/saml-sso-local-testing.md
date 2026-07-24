# Local SAML SSO testing

To exercise the SP-initiated SSO login flow end-to-end against a real Identity
Provider on your machine, use the throwaway Keycloak IdP in
[bikeindex/saml-idp-test](https://github.com/bikeindex/saml-idp-test). Its README
is a step-by-step runbook (generate a dev SP keypair, boot Keycloak, configure a
local org, log in).

The SP signs its AuthnRequests, so `SAML_SP_CERTIFICATE` / `SAML_SP_PRIVATE_KEY` must be set
in `.env.local` — without them the IdP rejects every login (`SigAlg was null`). Keep those
names out of `.env`: `bin/dev` runs foreman, which injects `.env` into every process, and
dotenv won't overwrite an already-set name, so even a blank value there silently wins.
Check the running server with:

```bash
curl -s "$BASE_URL/sso/sso-test/metadata" | grep -c X509Certificate
```

`0` means no keypair loaded.

This is a **manual sanity check** — nothing here depends on it. The deterministic,
CI-covered assertion/routing/provisioning coverage lives in
`spec/requests/saml_callback_request_spec.rb`, which signs its own assertions
in-process with no container.
