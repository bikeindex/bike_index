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
