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

## What to test (and what not to)

- Tests should either: help make the code correct now, or prevent bugs in the future. Don't add tests that don't do one of those things.
- Use **request specs**, not controller specs. Everything making the same request should be in a single test.
- Avoid testing private methods.
- Avoid mocking objects.
  - If making external requests, use VCR. Don't manually write VCR cassettes — record them by running the tests.

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
