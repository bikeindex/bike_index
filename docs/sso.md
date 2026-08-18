# SAML SSO

Bike Index is a SAML 2.0 **Service Provider**. An organization's Identity Provider
authenticates its people; we consume the assertion, link or create an account, and sign
them in. Everything is per-organization and slug-scoped:

| Endpoint | Purpose |
|---|---|
| `/sso/<slug>/metadata` | our SP metadata — the URL you hand an IdP admin |
| `/sso/<slug>/init` | SP-initiated login |
| `/sso/<slug>/callback` | Assertion Consumer Service |

All three 404 unless the organization has the `saml_sso` feature. `init` and `callback`
additionally need the configuration marked live.

Code: `saml_controller.rb`, `app/services/saml/`, `app/models/organization_saml_configuration.rb`.
Deterministic coverage lives in `spec/requests/saml_callback_request_spec.rb`, which signs
(and encrypts) its own assertions in-process.

## Trust: two certificates, neither bought from a CA

SAML trust comes from the metadata two parties exchange, not from a CA chain — a self-signed
certificate is correct here, not a shortcut.

| | Ours (the SP) | Theirs (the IdP) |
|---|---|---|
| What | `SAML_SP_CERTIFICATE` / `SAML_SP_PRIVATE_KEY` | `organization_saml_configuration.idp_cert` |
| Scope | one keypair, app-wide | one per organization |
| Source | we generate it | they hand it to us from their metadata |
| Secret? | certificate is public; **the private key is the only secret** | public |
| Stored | environment variables | database, pasted in the admin SAML card |

Our certificate is published at `/sso/<slug>/metadata` for anyone to fetch — that is its
entire job. The one keypair appears there twice, under a `signing` and an `encryption`
KeyDescriptor: the first is what an IdP checks our AuthnRequest signatures against, the
second is what an IdP that encrypts assertions encrypts to.

**Encryption is the IdP's decision, and there is no switch on our side.** We publish the key
and decrypt whatever arrives; `want_assertions_encrypted` is metadata-only in ruby-saml
(verified against 1.18.1 — it appears at `settings.rb:293` and `metadata.rb:71` and is never
read during response validation). Decryption fires whenever an `<EncryptedAssertion>` is
present and an SP private key exists. Turning the flag off would not reject an encrypted
assertion; turning it on does not require one.

**No session cookie is involved.** The ACS is a cross-site POST, and a `SameSite=Lax` cookie
isn't sent on one — so the SAML transaction rides in `RelayState`, with the state in Redis
(`Saml::RequestStore`, single-use via `GETDEL`, 10-minute TTL). The accepted tradeoff is
recorded in `saml_controller.rb#callback` above the `claim` call. `SameSite=None` is not on
the table.

## Onboarding an organization

1. **Grant the `saml_sso` feature.** It is calculated from a paid invoice carrying an
   `OrganizationFeature` with that slug — not a checkbox on the organization. Set the amount
   due to `0` to comp it, and leave coverage starting today; a future start date leaves the
   invoice inactive. A Sidekiq worker must be running, or `enabled_feature_slugs` never
   updates and nothing downstream appears.
2. **Set `user_email_domain`** — bare domain, no `@`, must contain a dot. The field only
   renders once a domain feature is enabled, which is why it comes after the invoice.
3. **Send them `https://bikeindex.org/sso/<slug>/metadata`.**
4. **Take their IdP metadata** and fill the SAML card on the organization's admin edit page
   (superadmin only): IdP entityID, IdP SSO target URL, signing certificate.
5. **Set the email attribute if needed.** We default to the `mail` OID
   (`urn:oid:0.9.2342.19200300.100.1.3`). Some IdPs release an empty `mail` and carry the
   address in `eduPersonPrincipalName` (`urn:oid:1.3.6.1.4.1.5923.1.1.1.6`) instead — check
   their attribute release policy. With no attribute match we fall back to the NameID.
6. **Tick "Enable live SAML login."**

Two things to know before promising anyone a smooth setup:

- **`user_email_domain` is rendered disabled unless the admin has the `developer?` flag.**
  Since the SAML card requires a domain, a plain superuser cannot complete onboarding
  through the UI at all.
- **The organization admin cannot configure SAML themselves.** Every SAML field is on the
  Bike Index admin form. Their only job is passing the metadata URL to whoever runs their IdP.

### What `user_email_domain` does

Two jobs, and the second is a security boundary:

- **Routing.** Anyone typing an address on that domain at `/session/new` is redirected to the
  IdP instead of being offered a password.
- **Authorization.** Every assertion is checked against it — an IdP may only sign in
  addresses on the domain its organization claims (`assertion_processor.rb`, via
  `Organization.saml_email_matching`). Without it a misconfigured IdP could assert any
  address, including a superuser's, and be believed.

One SSO organization per domain (uniqueness-guarded), and step 6 won't save without it.

### Verifying

```bash
curl -s "https://<host>/sso/<slug>/metadata" | grep -o "KeyDescriptor use='[a-z]*'" | sort -u
```

Expect both `encryption` and `signing`, carrying the same certificate. No output means no
keypair is loaded — the environment variables are missing or were mangled in transit. Also
confirm the `entityID` and ACS URL use the real public host: they derive from `BASE_URL`, and
if that is wrong the IdP POSTs somewhere unreachable or the assertion fails audience validation.

## The SP keypair

One keypair serves every organization. Generate it anywhere — it is ordinary `openssl` output
with no host binding, and the CN is cosmetic:

```bash
bundle exec rake saml:generate_sp_keypair        # YEARS=50 unless overridden
```

It prints both PEMs labelled with the environment variables they belong in. Nothing is
written to disk and nothing touches the database. **Never write the private key to a file you
don't delete.**

Long expiry is deliberate — see rotation. Past 2049, X.509 switches the validity dates from
UTCTime to GeneralizedTime; the 50-year default crosses that line, which our stack handles but
an unusual IdP might not. `YEARS=20` stays on UTCTime if one ever balks.

### Where it lives

The private key goes exactly where `SECRET_KEY_BASE` already goes for that environment. It is
not a new category of secret and needs no new infrastructure.

- **Production (Cloud 66)** — stack-level environment variables, so every server and container
  receives them. Per `.cloud66/manifest.yml`, environment changes need a **hard restart**; the
  phased-restart signal will not pick them up.
- **Sandbox and review apps (Kamal)** — four places, mirroring any existing secret: the
  1Password item `Kamal/BikeIndex Review`, `.kamal/secrets` (fetch list + an `extract` line
  each), `.kamal/secrets-ci` plus matching GitHub Actions secrets, and the `env: secret:` list
  in `config/deploy.review.yml` or they never reach the container.
- **Development** — already wired; `.env.local` points at the committed test keypair in
  `spec/fixtures/saml/`.

**The PEM newline hazard.** A PEM is multi-line and both deploy paths pass secrets through
parsers that can mangle embedded newlines. The failure is silent: the certificate fails to
parse and the metadata simply omits the `<KeyDescriptor>` rather than erroring. Always verify
after setting rather than assuming it took.

### Rotation

**Nothing pushes an update to anyone.** Every partner IdP holds a copy of our certificate,
taken from our metadata at onboarding. A new certificate takes effect for an organization only
once that organization's IdP admin re-consumes our metadata. Rotation is therefore a
coordination exercise with every partner at once — which is why the default life is 50 years.

**Overlap is possible but isn't wired up.** ruby-saml's `sp_cert_multi` publishes independent
signing and encryption keypairs, signs with the first, and tries *every* encryption key when
decrypting — so an assertion encrypted to either the old or new certificate still opens.
`certificate_new` is the lighter variant, publishing a second certificate over the same
private key. `SettingsBuilder#assign_sp` sets the single-keypair form, and ruby-saml refuses
`sp_cert_multi` alongside it — so adopting overlap is a code change, much easier to make
before a rotation than during one.

**Expiry fails quietly.** `security[:check_sp_cert_expiration]` is left at its default of
false, so an expired certificate is still loaded, published, and used to sign. Nothing warns
and nothing watches the date.

## Testing

**Encrypted round trip, locally.** Use the throwaway Keycloak IdP in
[bikeindex/saml-idp-test](https://github.com/bikeindex/saml-idp-test); its README is a
step-by-step runbook. Keycloak is the only IdP in reach that will encrypt assertions to our
published key, which is the one thing the hosted test IdPs cannot do.

`SAML_SP_CERTIFICATE` / `SAML_SP_PRIVATE_KEY` must be in `.env.local`, or the IdP rejects every
login with `SigAlg was null`. Keep those names out of `.env`: `bin/dev` runs foreman, which
injects `.env` into every process, and dotenv won't overwrite an already-set name — so even a
blank value there silently wins.

**Full rehearsal against a public IdP.** Use [mocksaml.com](https://mocksaml.com). Nothing to
create: it has no accounts and no per-SP registration, reading the ACS URL and audience
straight out of the AuthnRequest.

| Bike Index field | Value |
|---|---|
| IdP entityID | `https://saml.example.com/entityid` |
| IdP SSO target URL | `https://mocksaml.com/api/saml/sso` |
| IdP certificate | the `<X509Certificate>` body from `https://mocksaml.com/api/saml/metadata` |

Its login password is `samlstrongpassword`; username is free text but the domain is a two-item
dropdown, so set the organization's `user_email_domain` to `example.com`. The NameID comes back
as `<username>@<domain>` with `id` / `email` / `firstName` / `lastName` attributes — plain
names, not the OIDs a university IdP sends, so the NameID fallback is what carries the email
unless you set the attribute to `email`.

**Last verified 8/15** on the Railway staging box against mocksaml over real HTTPS: a first
login provisioned and confirmed a new account, a second login on the same address reused it,
and a third linked to a pre-existing account. That exercises the signed AuthnRequest, the
cross-site POST, RelayState claim, signature validation, `InResponseTo` matching, and
provisioning. What it does **not** cover: encryption (mocksaml publishes only a signing key and
never ingests an SP certificate, so it structurally cannot encrypt to us) and attribute
mapping.

**Don't test IdP-initiated login.** Starting at the IdP produces an assertion with no
`InResponseTo` and the callback rejects it. That is deliberate replay protection.

**Don't use samltest.dev.** It emits schema-invalid assertions — an empty `InResponseTo`
(not a valid `xs:NCName`) on every login, plus raw UUIDs as element IDs — and ruby-saml rejects
them at `validate_structure` before the signature check. Deterministic, 100% failure. Measured,
not inferred.

Before meeting a partner, do a pass on an **Okta or Auth0 free developer account** — closest to
what they actually run, and the only way to exercise real attribute mapping on their own domain.

## When it doesn't work

Failures surface as a flash on `/session/new` reading `Unable to sign in via SSO: <reason>`.
The reason is the real one — ruby-saml's validation errors are passed through, not swallowed.

| Reason | Cause |
|---|---|
| `/sso/<slug>/metadata` 404s | feature not enabled, or `UpdateOrganizationAssociationsJob` hasn't run |
| `/sso/<slug>/init` 404s | config incomplete — needs enabled + entityID + SSO URL + cert |
| `this login has expired` | RelayState token already claimed or older than 10 minutes |
| `SAML session mismatch` | the `org_slug` in RelayState isn't the org being called back |
| audience / destination errors | `BASE_URL` doesn't match the host you're browsing |
| `InResponseTo` errors | IdP-initiated login, or a stale AuthnRequest |
| `assertion is missing an email` | NameID isn't an email and no email attribute matched |
| `is not on this organization's SSO domain` | the asserted address isn't on `user_email_domain` |
| `Not match the saml-schema-protocol-2.0.xsd` | the IdP emitted structurally invalid XML |
| signature failures mentioning no certificate | the SP keypair didn't survive deploy — check metadata |

## Before flipping an organization live

What changes under people who already have accounts. Nothing here is a production count — these
are the cohorts to go count.

**Announce it first.** `redirect_forced_saml` fires on submit, not on render: the login form
still draws, and the redirect happens once the email is posted. Nobody is emailed. Anyone on
that domain who has been using a password just starts landing at the IdP. This is the cohort
most likely to generate support tickets.

**Check for superusers on the domain.** The guard has no bypass. If the IdP config is wrong or
the IdP is down, an admin whose address is on that domain cannot get in with a password. Move
the address, or keep at least one admin account off-domain.

**Sweep the data first.** `user_email_domain` predates its own validations, so a row containing
`@`, missing a `.`, or duplicating another organization makes that record unsaveable — an admin
editing an unrelated field gets a validation error they didn't cause. Duplicates across SSO orgs
resolve by query order. Check for consumer domains (`gmail.com`) sitting in that column, and for
organizations with a domain set but neither feature enabled — enabling either changes behavior
for everyone on the domain immediately, with no staged rollout.

**The secondary-email asymmetry** is the likeliest thing to be missed, because the two halves
disagree. Routing keys off the single submitted string; linking searches confirmed
`user_emails` first (`User.fuzzy_confirmed_or_unconfirmed_email_find`). So a user whose primary
address is off-domain but who holds a confirmed secondary on the SSO domain is *not* forced to
SSO — they type their primary and get a password prompt as always. Forced SSO is effectively
opt-out for anyone willing to make a personal address primary. If that same user does go
through the IdP, they link to the existing account rather than getting a duplicate.

**Pin the NameID format with the IdP.** `SsoIdentity` is unique on
`(organization_id, provider, uid)` where `uid` is the asserted NameID. A **transient** NameID
mints a new identity row on every login. `name_id_format` is stored but never enforced — and
there is no field for it on the admin form, though it is in the strong params.

**Capture before you change anything**, so it's reversible: the org's `enabled_feature_slugs`,
the ids of existing `organization_roles`, accounts on the domain split by has-a-password /
passwordless / unconfirmed / banned / superuser, accounts whose confirmed secondary is on the
domain but whose primary isn't, and outstanding password-reset tokens on any of them.

## Open decisions

Things code cannot settle, ordered by what blocks rollout soonest.

**What role, if any, does a first SSO login grant?** This is the hard gate. SSO provisioning
itself grants nothing — `provision_user` calls `UserServices::PasswordlessCreator` directly.
Roles come from the separate opt-in `user_role_for_user_email_domain` feature, which grants a
hardcoded `member` (`OrganizationRole.create_for_user_email_domain`). `member` carries edit
rights, which is wrong for a school; `member_no_bike_edit` grants search without edit, which is
the student case. A single hardcoded value cannot serve both, so the default has to come from
somewhere: per-organization configuration, organization `kind`, or nothing at all. Changing it
is a code change, not config.

Worth knowing when this gets discussed: organization permissions have three axes, and roles are
the weakest. Only `admin` / `member` / `member_no_bike_edit` exist, and for access purposes
there are effectively two levels — `Organized::BaseController` gates on `ensure_member!`, so
**any** claimed role gets the org's bike list and search. `member_no_bike_edit` restricts
editing, not visibility. Most real capability lives in organization *features* (bought per
organization, not per user), and organization `kind` gates nothing at all.

**What does "forced SSO" mean — the IdP is the only way in, or we just don't hand out
passwords?** `redirect_forced_saml` keys off a submitted email, so it structurally cannot fire
on paths that authenticate by redeeming a **token**. One is live: `send_password_reset_email` is
unguarded, so a user on an SSO domain can request a reset at any time and end up with a working
password *and* a session. Two are bounded — magic links minted before the org moved to SSO keep
working for 2h, and confirmation tokens can no longer be minted for an SSO email. The unifying
property is that all of them authenticate on **mailbox possession**, which is exactly what
forced SSO is meant to take out of the loop; the sharp consequence is MFA bypass, since an IdP
may enforce Duo or a hardware key and none of these paths do. Guarding the live path has a real
cost: it strands anyone holding a pre-SSO local account. Impact is bounded to the *identity* —
these paths grant an account and session, not organization access.

**Who provisions and rotates the production SP keypair?** Not a code task, and on the critical
path: until `SAML_SP_CERTIFICATE` / `SAML_SP_PRIVATE_KEY` exist in the production environment,
metadata advertises no certificate at all and an IdP has nothing to encrypt to. Per standing
arrangement the private key lives with Seth, not with us. Also needs a rotation answer — how
much notice before expiry, and whether rollover uses overlapping certificates (the code change
above) or a flag day.

**What does an SSO user see instead of a signup form?** A silent redirect to the IdP, or an
interstitial explaining their organization manages sign-in. Industry norm is home-realm
discovery: one email box, SSO-managed domains never see a password field, and the account comes
into existence via JIT provisioning. We already have the mechanism — identifier-first login is
merged and `redirect_forced_saml` already covers registration.

**Deprovisioning.** JIT provisioning has no offboarding story: when someone leaves, the IdP
stops authenticating them but their account and role persist. SCIM is the usual answer and
enterprise buyers ask for it. Combined with the mailbox-possession paths above, a departed
employee keeps a usable account indefinitely.

**One email domain per organization?** `user_email_domain` is a single column with a uniqueness
guard, so an org with several domains (`example.edu` + `alumni.example.edu`) can't be expressed.
Not blocking unless a customer needs it.

## Accepted gaps

- **Nothing deprovisions.** Removing someone in the IdP stops them signing in again; it does not
  remove a role they already hold.
- **Unconfirmed accounts are force-confirmed by the first assertion.** Deliberate — otherwise
  sign-in bounces to the confirm-email page — but an address the organization never verified
  becomes confirmed on the IdP's say-so.
- **Banned users are rejected only after the identity is written.** `sign_in_and_redirect` blocks
  them, so this isn't a way back in, but they accumulate `SsoIdentity` rows and a flipped
  `confirmed` flag.
- **Users on the domain who belong to a different organization** get routed through this
  organization's IdP. Their other role is untouched, but their login path is now owned by an org
  they may have no relationship with. Most likely with contractors and shared or alumni domains.
- **Email changes at the IdP go stale.** If the NameID is stable, `identity.email` refreshes but
  `user.email` never does. If the NameID *is* the email and it changes, the lookup misses both
  and provisioning mints a duplicate account. Merging duplicates is manual.
- **The invitation counter can go negative.** `sent_invitation_count` counts all
  `organization_roles`, so auto-granted roles count against `available_invitation_count`.
  Enforcement is skipped for exactly these orgs, so nothing breaks — the admin page just shows a
  negative remaining count.

## Settled — don't re-litigate

- **Fall-through when the config isn't live.** An org with `saml_sso` but an unconfigured
  `organization_saml_configuration` returns nil from `saml_email_matching`, the guard doesn't
  fire, and the user signs up normally. Deliberate, specced, endorsed.
- **JIT provisioning sets no password.** Always correct; a password account observed during
  testing came from `/users/new`, a different controller.
- **Login-CSRF via RelayState.** Accepted and documented in `saml_controller.rb`. The mitigation
  would be a dedicated `SameSite=None` cookie; `SameSite=None` is not going in this codebase. No
  victim account is taken over — the attacker's own account is the one exposed.
- **`GETDEL`'s Redis ≥ 6.2 floor.** We run 6–7+ across the stack. Redis is already a hard
  app-wide dependency with no rescues anywhere, so a Redis too old for `getdel` breaks far more
  than SSO. Same reasoning rejects special-casing Redis connection errors here.
- **Advertise encryption always**, no per-organization column. The flag is metadata-only, so a
  per-org switch controls nothing an IdP can't already do, and an IdP that doesn't encrypt
  ignores the extra KeyDescriptor.
- **No SLO.** The route never existed; the metadata advertisement was removed 8/14 with a
  regression spec. Advertising an endpoint that 404s hands a partner a broken URL at onboarding.
- **ruby-saml version pin.** No pin — we trust the project's own coverage.
- **Backfill of orgs auto-granting roles** is manual, not a data migration. There are no SSO
  organizations in production, so the cohort is empty today.
