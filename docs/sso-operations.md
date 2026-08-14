# Running SAML SSO

Operator guide: provisioning the Service Provider (SP) keypair, and onboarding an
organization onto SSO. For exercising the login flow on a laptop, see
[sso-local-testing.md](sso-local-testing.md).

## Two certificates, neither bought from a CA

Nothing here involves a certificate authority. SAML trust comes from the metadata
two parties exchange, not from a CA chain — so a self-signed cert is correct, not a
shortcut.

| | Ours (the SP) | Theirs (the IdP) |
|---|---|---|
| What | `SAML_SP_CERTIFICATE` / `SAML_SP_PRIVATE_KEY` | `organization_saml_configuration.idp_cert` |
| Scope | One keypair, app-wide | One per organization |
| Source | We generate it (below) | They hand it to us from their IdP metadata |
| Secret? | Certificate is public; **private key is the only secret** | Public |
| Stored | Environment variables | Database, pasted in the admin SAML card |

Our certificate is published at `/sso/<org-slug>/metadata` for anyone to fetch —
that is its entire job. Only the private key is sensitive. The one keypair appears
there twice, under a `signing` and an `encryption` KeyDescriptor: the first is what
an IdP checks our AuthnRequest signatures against, the second is what an IdP that
encrypts its assertions encrypts to.

## Generating the SP keypair

One keypair serves every organization. Generate it anywhere — a laptop is fine, it
is ordinary `openssl` output with no host binding:

```bash
bundle exec rake saml:generate_sp_keypair        # YEARS=50 unless overridden
```

It prints both PEMs already labelled with the environment variable names they belong
in, plus the expiry date. Nothing is written to disk and nothing touches the database.

The CN is cosmetic; IdPs trust the key through our metadata, not a hostname check.

Long expiry is deliberate — see rotation below. Past 2049 X.509 switches the validity
dates from UTCTime to GeneralizedTime; the default 50 years crosses that line, which our
stack handles but an unusual IdP might not. `YEARS=20` stays on UTCTime if one ever balks.

Never write the private key to a file you don't delete. It belongs only in the
environment's secret store.

## Where the keypair lives, per environment

The private key goes exactly where `SECRET_KEY_BASE` already goes for that
environment — it is not a new category of secret, and needs no new infrastructure.

**Production (Cloud 66).** Set both variables as stack-level environment variables
in the Cloud 66 dashboard. Stack-level means every server and container in the
stack receives them, which is what makes this safe across a multi-server deploy.
Per `.cloud66/manifest.yml`, **environment variable changes require a hard restart**
— the phased-restart signal will not pick them up.

**Sandbox and review apps (Kamal).** Four places, mirroring any existing secret:

1. The 1Password item `Kamal/BikeIndex Review` (account `bike-index`)
2. `.kamal/secrets` — the `kamal secrets fetch` list, plus an `extract` line each
3. `.kamal/secrets-ci` — plus matching GitHub Actions repository secrets, since CI
   deploys read the env passthrough rather than 1Password
4. `config/deploy.review.yml` — the `env: secret:` list, or they never reach the
   container

**Development.** Already wired: `.env.local` points both variables at the committed
test keypair in `spec/fixtures/saml/`. Nothing to generate.

### The PEM newline hazard

A PEM is multi-line, and both deploy paths pass secrets through parsers that can
mangle embedded newlines. The failure is silent: the certificate fails to parse,
and the metadata simply omits the `<KeyDescriptor>` rather than erroring.

Always verify after setting them (see below) rather than assuming it took.

## Rotating the SP keypair

Rotation is run by whoever holds the private key, which is deliberately not the people
who write this code. What follows is what the application actually supports, so a policy
can be written against real constraints rather than assumed ones.

**The constraint.** Every partner IdP holds a copy of our certificate, taken from our
metadata when they onboarded. Nothing pushes an update to them. A new SP certificate only
takes effect for an organization once that organization's IdP administrator re-consumes
`https://bikeindex.org/sso/<org-slug>/metadata`. Rotation is therefore a coordination
exercise with every partner at once — which is why the generated certificate defaults to
a ten-year life.

**Overlap is possible, but isn't wired up.** ruby-saml can publish more than one SP
certificate, which is what lets a rollover happen without a synchronized cutover:

- `sp_cert_multi` takes independent signing and encryption keypairs. Metadata publishes
  all of them, AuthnRequests are signed with the first signing entry, and decryption tries
  *every* encryption key in turn — so an assertion encrypted to either the old or the new
  certificate still opens.
- `certificate_new` is the lighter variant: it publishes a second certificate but reuses
  the same private key, so it covers re-issuing an expiring certificate over an existing
  key rather than replacing the key itself.

`Saml::SettingsBuilder#assign_sp` sets `settings.certificate` and `settings.private_key`,
the single-keypair form, and ruby-saml refuses `sp_cert_multi` alongside those two. So
adopting overlap is a code change here, not two more environment variables — and it is
much easier to make before a rotation than during one.

**Expiry fails quietly on our side.** `security[:check_sp_cert_expiration]` is left at its
default of false, so an expired SP certificate is still loaded, still published, and still
used to sign. Nothing in the app warns, and nothing watches the date. Whether logins
actually break is up to each IdP's own validation.

**Open questions for whoever owns the key:**

- How much notice before expiry, and who is watching that date?
- Is a rollover run with overlapping certificates (which needs the code change above), or
  as a flag day coordinated with every partner at once?
- What is the recovery path if the private key is lost? Today that means generating a new
  keypair and walking every organization through re-consuming our metadata.

## Onboarding an organization

1. **Enable the `saml_sso` feature.** It is a calculated column — it comes from a
   paid invoice carrying an `OrganizationFeature` with that slug, not from editing
   the organization directly.
2. **Set `user_email_domain`** to the domain the organization's users log in with.
   It does two jobs: it routes a typed email to their IdP, and it is what every
   assertion coming back is authorized against — an IdP may only sign in addresses on
   the domain its organization claims. Note the implications: once set alongside
   `saml_sso`, every login attempt from that domain is redirected to the IdP — no
   password, no new magic link. One SSO organization per domain, and step 6 won't save
   without this set.
3. **Send them our metadata**: `https://bikeindex.org/sso/<org-slug>/metadata`.
4. **Take their IdP metadata** and fill in the admin SAML card (superadmin only, on
   the organization's admin edit page): IdP entityID, IdP SSO target URL, and their
   signing certificate.
5. **Set the email attribute if needed.** We default to the `mail` OID
   (`urn:oid:0.9.2342.19200300.100.1.3`). Some IdPs release an empty `mail` and
   carry the address in `eduPersonPrincipalName` instead — check their attribute
   release policy and override `email_attribute_name` if so.
6. **Check "Enable live SAML login."** Until this is on, the SSO endpoints 404.

## Verifying

```bash
curl -s "https://<host>/sso/<org-slug>/metadata" | grep -o "KeyDescriptor use='[a-z]*'" | sort -u
```

Expect both, carrying the same certificate:

```
KeyDescriptor use='encryption'
KeyDescriptor use='signing'
```

No output at all means no keypair is loaded — the environment variables are missing or
were mangled in transit. Also confirm the `entityID` and the AssertionConsumerService
URL are the real public host: they derive from `BASE_URL`, and if that is wrong the
IdP will POST to somewhere unreachable, or the assertion will fail audience
validation.

## Known gaps

- The metadata advertises a Single Logout URL, but no SLO route exists yet.
- **Signing in grants no role.** An SSO login links the account and signs it in; it never
  adds anyone to the organization. Roles come from the separate
  `user_role_for_user_email_domain` feature, and that only fires as an account is
  confirmed — so people who already had a confirmed Bike Index account before their
  organization moved to SSO keep signing in with no organization role at all.
- **Nothing deprovisions.** Removing someone in the IdP stops them signing in again; it
  does not remove a role they already hold.
- A magic link issued before an organization moved to SSO keeps working until that
  token expires (two hours).
- Password reset still signs in a domain user without touching the IdP, for anyone
  holding an account that predates the organization's move to SSO.
