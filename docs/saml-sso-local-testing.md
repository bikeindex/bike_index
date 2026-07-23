# Local SAML SSO testing

To exercise the SP-initiated SSO login flow end-to-end against a real Identity
Provider on your machine, use the throwaway Keycloak IdP in
[bikeindex/saml-idp-test](https://github.com/bikeindex/saml-idp-test). Its README
is a step-by-step runbook (generate a dev SP keypair, boot Keycloak, configure a
local org, log in).

This is a **manual sanity check** — nothing here depends on it. The deterministic,
CI-covered assertion/routing/provisioning coverage lives in
`spec/requests/saml_callback_request_spec.rb`, which signs its own assertions
in-process with no container.
