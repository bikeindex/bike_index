---
name: rspec-testing
description: >-
  Bike Index's RSpec testing conventions — how to structure specs with
  `context` and `let`, what kinds of tests to write, and what to avoid
  (mocks, controller specs, testing private methods). Trigger when writing
  or modifying any `*_spec.rb` file, adding test coverage for new code,
  refactoring tests, or designing the test layout for a new feature.
  Includes Good/Bad examples of the project's preferred style.
---

# RSpec testing in Bike Index

This project uses RSpec. All business logic should be tested.

## Run only the specs your change touches

Pass the files or directories you changed — `bundle exec rspec spec/components/ui/table spec/requests/bikes/show_request_spec.rb`. Never run a bare `bundle exec rspec`, `spec/`, or a whole top-level directory like `spec/components` or `spec/requests`: those take many minutes and sweep in `:flaky`-tagged system specs. CI runs the full suite.

When something fails outside the files you changed, re-run that spec file on its own before treating it as yours. Failing alone means it's real, and a real failure gets fixed, never excused as pre-existing. Passing alone means the full run was order-dependent or flaky — that's the [`fixing-flaky-failures`](../fixing-flaky-failures/SKILL.md) skill, and its first rule is that you can't reach for a retry, a looser matcher, or a deleted assertion to make it green.

## What to test (and what not to)

- Tests should either: help make the code correct now, or prevent bugs in the future. Don't add tests that don't do one of those things.
- Use **request specs**, not controller specs — request specs go through the full middleware/routing stack, so they catch breakage controller specs can't see. Everything making the same request should be in a single test. For markup a component owns, see [A component's own markup](#a-components-own-markup-is-tested-in-its-component-spec).
- Avoid testing private methods.
- Avoid mocking objects.
  - If making external requests, use VCR. Never write or edit a cassette by hand — record them by running the tests (see [VCR cassettes](#vcr-cassettes-never-hand-edit-always-re-record)).
- Don't use `tap` to bundle factory creation with follow-up setup. Create the record in `let`/`let!`, then do the follow-up work on its own line (a separate statement, or a `before` block). One thing per line reads better and keeps the factory call clean.

### Good

```ruby
let!(:bike_transferred) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
before { BikeServices::OwnershipTransferer.find_or_create(bike_transferred, updator: user, new_owner_email: "new@example.com") }
```

### Bad

```ruby
let!(:bike_transferred) do
  FactoryBot.create(:bike, :with_ownership_claimed, user:).tap do |bike|
    BikeServices::OwnershipTransferer.find_or_create(bike, updator: user, new_owner_email: "new@example.com")
  end
end
```

## A component's own markup is tested in its component spec

What a component decides about its markup — a label, a placeholder, a class, whether a field renders at all — belongs in `spec/components/**/component_spec.rb`, not in the request spec for a page that happens to render it. Request specs cover the request: status, redirects, what was saved, what the page is wired to.

A component having no spec yet isn't a reason to put it in the request spec instead. `spec/components/register/step2/component_spec.rb` is the pattern, including the `render_x` helper that reloads the record so an object updated mid-example isn't answered from the copy the previous render left behind.

## `render_in_view_context` takes its subjects as method arguments

A component needing a `form_builder` renders inside `render_in_view_context { form_for … }`, which `instance_exec`s its block in the view context — so `let` values aren't in scope and a bare `organization` raises `NameError`. Wrap it in a `def rendered_component(organization, current_user)` and call that from the `let(:component)`; the block closes over the method's locals. `spec/components/admin/organizations/form/wrapper/component_spec.rb` is the pattern.

## `display_dev_info?` is false in test, so nothing it gates is verifiable

`ControllerHelpers#display_dev_info?` opens with `!Rails.env.test?`. Every `only-dev-visible` block it wraps is unrendered in the suite, so threading the flag through a component — a wrong default, a missed hop — passes green and is wrong only in development. Reading the call sites isn't enough either — it can't show that a `UI::Table` cell block is `instance_exec`'d, so an `@ivar` in one resolves against the table and is always nil. Check it in the browser signed in as `dev@bikeindex.org`; the flag needs `developer?` *and* MiniProfiler, so the superadmin banner button won't do it.

## `log_in` stubs the auth lookup, so it can't answer whether a session ends

`spec/support/request_spec_helpers.rb`'s `log_in` (and every `:request_spec_logged_in_as_*` context) stubs `User.from_auth` to return the user, so the cookie is never read and the session outlives anything done to that user — deleting, banning, rotating their `auth_token`. A spec asserting a request signs someone *out* has to sign in for real: `post "/session", params: {session: {email:, password:}}`, then make the request. `spec/requests/sessions_request_spec.rb`'s "deleted after signing in" is the pattern.

## VCR cassettes: never hand-edit, always re-record

**Never open a cassette and change it.** Not a URL, not a token, not a timestamp, not an interaction — no matter how small or how obviously right the edit looks. A cassette is a recording of what a real service actually said; an edited one asserts something no service ever returned, and the spec passes against a fiction. This has no exceptions.

The only way a cassette changes is a spec run that records it:

- **Stale or wrong contents** — `rm` the file and run the spec. VCR writes it from scratch, holding exactly the requests the spec makes now. Re-recording *without* deleting only writes back the requests still being made, so interactions the spec has stopped making survive forever — and because VCR times `re_record_interval` from the cassette's oldest interaction, one stale entry re-triggers re-recording on every run.
- **Cassette missing for a resource that doesn't exist yet** — leave it absent and the spec red. Don't fabricate one.
- **Secrets** — `spec/rails_helper.rb`'s `filter_sensitive_data` and `before_record` handle them. Add the key there; don't scrub the file by hand.

**Commit what a run re-records.** A modified cassette is a re-recording, not unrelated churn — cassettes carry a `re_record_interval` and are meant to update. Commit it on the branch you're on, whatever that branch is about. Never `git checkout` it away to keep a diff focused.

`git status` after a spec run is the only signal; a run that re-records prints nothing.

## Stubbing ENV

Never partial-mock `ENV` with `allow(ENV).to receive(:[]).and_call_original` — it makes every subsequent `ENV[...]` lookup go through RSpec's message router, which is slow and easy to break by forgetting a `.with(...)` branch.

Use `stub_const` against a merged hash instead:

### Good

```ruby
stub_const("ENV", ENV.to_hash.merge("STRIPE_SECRET_KEY" => "sk_test_123"))
```

### Bad

```ruby
allow(ENV).to receive(:[]).and_call_original
allow(ENV).to receive(:[]).with("STRIPE_SECRET_KEY").and_return("sk_test_123")
```

## Drain Sidekiq jobs, don't run them inline

Run enqueued jobs by draining them in the default fake mode — `SomeJob.drain` for one job, `Sidekiq::Job.drain_all` for everything (clear first with `Sidekiq::Job.clear_all` when earlier setup left jobs queued). Don't wrap the exercise in `Sidekiq::Testing.inline!`. Draining lets the request finish and commit before the jobs run, against that committed state — the way production does it — and keeps the test from silently pulling in every cascading job.

## Always fix failing tests

Fix every failing test, even ones that were already failing on `main`. Confirming a failure pre-dates your branch (via `git stash` or checking out `main`) explains *what* broke — not whether you fix it. You fix it.

## Don't weaken assertions to make a failing test pass

When a test goes red, the correct move is **investigate why**, not edit the assertion to match the new output. Watch for these tempting "fixes" that are actually erasing signal:

- Changing an expected value to whatever the page/chart/response now happens to render (e.g. `0` → `null`, an exact count → a range, a specific string → a substring/regex).
- Loosening `eq` to `include`, dropping `count:` constraints, or replacing `expect(...).to ...` with `expect(...).not_to be_nil`.
- Deleting the assertion entirely with a "looks unrelated" handwave.

The right loop: reproduce the failure, figure out *what* changed and *why*, then decide intentionally — fix the code if the original assertion captured the right behavior, or update the assertion (with a comment) if the behavior intentionally changed. If you're about to change a test "to make it easier", stop and explain why the new expectation is correct, not just convenient.

## Match a target attributes hash, not one attribute at a time

When you're checking several fields on the same object or response, build one expected-attributes hash and assert against it in a single matcher. Don't write a chain of one-attribute-per-line `expect`s.

- Object (ActiveRecord, plain Ruby): `expect(record).to have_attributes(target_attributes)`
- Hash (JSON response, parsed body): `expect(hash).to eq(target.as_json)` for full match, or `expect(hash).to include(target_attributes)` for partial.

This collapses what would be 4 brittle assertions into 1, makes the *contract* visible at a glance, and gives a single readable diff when something changes. It also avoids the trap of weak per-field assertions like `expect(x).to be_present` or `expect(url).not_to include("blank.png")` standing in for "the right value" — match the value directly.

### Good

```ruby
target_attributes = {kind: "found", impounded_description: "Some description"}
expect(impound_record).to have_attributes(target_attributes)

expect(json_result["memberships"]).to eq([target_membership.as_json])
```

### Bad

```ruby
expect(impound_record.kind).to eq("found")
expect(impound_record.impounded_description).to be_present
expect(impound_record.impounded_description).to eq("Some description")

logo_url = json_result["memberships"].first["organization_logo_url"]
expect(logo_url).to be_present
expect(logo_url).not_to include("blank.png")
expect(logo_url).to eq(organization.avatar_url)
```

The bad version spreads one logical assertion across many lines, mixes weak presence checks with the real expected value, and produces noisier failure output.

## Structuring with `context` and `let`

Use `context` and `let` to isolate what varies between examples. Each `it` block should live in a `context` that names the condition, with `let` overrides for only what differs in that case. **Avoid repeating setup across sibling `it` blocks.**

### Good

```ruby
describe "show_bulk_import?" do
  let(:organization) { FactoryBot.build(:organization, pos_kind:) }
  let(:pos_kind) { "no_pos" }

  it "is falsey" do
    expect(organization.show_bulk_import?).to be_falsey
  end

  context "when ascend" do
    let(:pos_kind) { "ascend_pos" }

    it "is truthy" do
      expect(organization.show_bulk_import?).to be_truthy
    end
  end

  context "when broken_ascend_pos" do
    let(:pos_kind) { "broken_ascend_pos" }
    it "is truthy" do
      expect(organization.show_bulk_import?).to be_truthy
    end
  end

  context "when lightspeed_pos" do
    let(:pos_kind) { "lightspeed_pos" }
    it "is truthy" do
      expect(organization.show_bulk_import?).to be_falsey
    end
  end

  context "when feature show_bulk_import_impound" do
    let(:organization) { FactoryBot.build(:organization_with_organization_features, enabled_feature_slugs: ["show_bulk_import_impound"]) }
    it "is truthy" do
      expect(organization.show_bulk_import?).to be_falsey
    end
  end
end
```

### Bad

```ruby
it "returns truthy for show_bulk_import?" do
  organization = FactoryBot.create(:organization, pos_kind: "ascend_pos")
  expect(organization.show_bulk_import?).to be_truthy
end
it "returns truthy when feature is included" do
  organization = FactoryBot.create(:organization)
  allow(organization).to receive(:any_enabled?) { true }
  expect(organization.show_bulk_import?).to be_truthy
end
```

The bad version repeats setup, mocks the object, and doesn't communicate what each case represents.

## One example per distinct setup — combine same-setup `it` blocks

`context`/`let`/`before` isolate what *varies*. The corollary runs the other way: if two sibling `it` blocks share the **same** setup — no differing `context`, `before`, or `let` override between them — collapse them into **one** example. Each distinct setup earns exactly one `it`; put all of that setup's assertions (and all of its requests/renders) in that single block.

This is the same instinct as "everything making the same request should be in a single test", generalized: splitting same-setup assertions across sibling `it` blocks re-runs identical setup (factories, HTTP requests, renders) once per block for zero isolation benefit, and scatters one logical behavior across the file. Two `it` blocks that differ *only* in the request params or the assertion — with identical `let`s and no `before` between them — are one example.

After writing a spec, scan each `context`/`describe`: if it holds multiple `it` blocks and they don't each sit behind a distinct `context`/`before`/`let`, merge them.

### Good

```ruby
context "superuser" do
  let(:current_user) { FactoryBot.create(:superuser) }

  it "offers every view and renders the owner and org-limited perspectives" do
    get "#{base_url}/#{bike.id}"
    expect(body_text).to match("View as owner of bike")

    get "#{base_url}/#{bike.id}", params: {view_as: "owner"}
    expect(body_text).to match("Your bike")

    get "#{base_url}/#{bike.id}", params: {view_as: "#{org.to_param}.limited"}
    expect(body_text).to match("Limited")
  end
end
```

### Bad

```ruby
context "superuser" do
  let(:current_user) { FactoryBot.create(:superuser) }   # re-created for every it below

  it "offers every view" do
    get "#{base_url}/#{bike.id}"
    expect(body_text).to match("View as owner of bike")
  end
  it "renders the owner view" do
    get "#{base_url}/#{bike.id}", params: {view_as: "owner"}
    expect(body_text).to match("Your bike")
  end
  it "renders an org panel as limited" do
    get "#{base_url}/#{bike.id}", params: {view_as: "#{org.to_param}.limited"}
    expect(body_text).to match("Limited")
  end
end
```

This only merges blocks whose setup is identical. Different setup still means separate examples, each in its own `context` with the `let`/`before` that differs — that's the section above, not a contradiction of it.
