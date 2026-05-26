---
name: integration-testing
description: >-
  Bike Index conventions for browser specs (`type: :system, :js`)
  — **always drive the spec through the real user-facing UI path**
  (no FactoryBot shortcuts for setup the user would actually perform,
  no `execute_script` bypasses for tricky widgets), every example
  pays a Selenium boot cost so bias hard toward fewer, denser examples
  that walk through state via clicks, prefer named-element matchers
  over CSS selectors, and combine same-setup work into one `it` even
  when scenarios feel independent. **Consult this skill any time you
  create or modify a `:js, type: :system` spec** — that includes
  everything under `spec/integration/` AND component system specs at
  `spec/components/**/*_system_spec.rb`; the rules apply equally to
  both. Read alongside the `rspec-testing` skill for the project's
  general `context`/`let` style.
---

# Integration testing in Bike Index

Browser specs (`type: :system, :js`) live in two places: feature flows under `spec/integration/` and component-level interaction specs at `spec/components/**/*_system_spec.rb`. Both run full Chrome sessions via Capybara/Selenium and pay a real Selenium boot cost per example, so the same conventions apply to both: optimize for fewer, denser examples and high-level Capybara helpers.

The general `context`/`let` style and "what to test" rules are in the [`rspec-testing`](../rspec-testing/SKILL.md) skill — the rules below extend it for the system-spec case.

## Always follow the real user path

This is the cardinal rule. The whole reason a system spec exists — over a cheaper request/model spec — is to verify the user-facing flow end-to-end. **If a user does it in the UI, the spec does it in the UI.** No FactoryBot shortcuts for state the user would build by clicking. No `execute_script` to drive widgets the user would type into. No visiting pre-baked URLs to skip a screen the user would navigate through.

**This applies to every step the example claims to cover**, including setup. If your spec describes "user signs in, registers a bike, follows the email link, signs up," then sign-in is a form submission, registration is the full bike form (manufacturer autocomplete and all), the email link is extracted from the actual delivered mail, and signup is the real form. Don't `FactoryBot.create(:bike, …)` to skip the bike form — the spec stops being an integration test the moment any of those steps becomes a model-layer shortcut.

**If the user path is hard to drive, that's a signal, not an excuse.** Common temptations and the right response:

- "Selectize/select2/autocomplete is flaky from Capybara" → drive the widget through its real UI (click, type, wait for the option, click it). If the dropdown never populates, debug *why* — the underlying bug is usually real (stale asset cache, missing seed data, wrong API URL, etc.) and worth fixing for production too.
- "Setting up this state through the UI takes 20 lines of clicking" → that's the integration spec working as intended; combine it with other assertions into one example (see "One `it` per setup") so the cost is paid once.
- "Just this one step via FactoryBot, then the rest through the UI" → no. The hybrid spec gives false confidence: it passes when the UI step is broken, because the UI step never ran.

When you find yourself reaching for an `execute_script` to set a value, a `FactoryBot.create` to skip a screen, or a constructed URL to jump past a redirect — stop, identify what's blocking the real path, and fix that instead. Production code bugs surfaced by integration specs are the integration spec doing its job.

The only legitimate exceptions are infrastructure the user wouldn't perform — seeding base reference data (color/cycle-type lookup tables that exist in production from migrations), creating an admin account that exists outside the user-facing flow, or stubbing genuinely external services (third-party APIs, Stripe, geocoders). When in doubt, ask: "would a real user have done this step before reaching the part I'm testing?" If yes, do it in the UI.

## One `it` per setup; many assertions per `it`

Unit specs prefer one assertion per example. **Integration specs prefer the opposite**: when several assertions share the same fixture and the same initial `visit`, fold them into one example that walks through state transitions (click → assert → click → assert).

Use `context` only when the *setup* differs — a different `let!`, a different page, a different feature flag. Don't split a single user flow across sibling `it` blocks just because each step has its own assertion.

**Combine same-setup work, even when scenarios feel independent.** Before writing a new `describe`/`context`/`it`, read the existing file and find an example whose fixtures and initial `visit` match what you need — then append your clicks/assertions to it. It's tempting to leave a separate `it` for things that feel like different concerns ("button-state test", "filter-persistence test", "URL-param test", "mobile-layout test"). Don't. A long, sectioned-with-comments example pays one Selenium boot; four short examples pay four. Failure attribution is fine — the failed line number tells you exactly which phase broke. Only add a new block when the setup genuinely differs.

### Good

```ruby
it "filters listings, persists filters across pagination, and clears them" do
  expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", count: 12)

  fill_in "Manufacturer", with: "Yuba"
  click_button "Search"

  expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", count: 8)
  expect(find_field("Manufacturer").value).to eq "Yuba"

  click_link "Next"

  expect(page).to have_current_path(/page=2/)
  expect(find_field("Manufacturer").value).to eq "Yuba"

  click_link "Clear filters"

  expect(find_field("Manufacturer").value).to be_blank
  expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", count: 12)
end
```

### Bad

```ruby
# Three browser sessions for what's effectively one user flow.
it "filters listings by manufacturer" do
  fill_in "Manufacturer", with: "Yuba"
  click_button "Search"
  expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", count: 8)
end

it "persists filters across pagination" do
  fill_in "Manufacturer", with: "Yuba"
  click_button "Search"
  click_link "Next"
  expect(find_field("Manufacturer").value).to eq "Yuba"
end

it "clears filters when Clear is clicked" do
  fill_in "Manufacturer", with: "Yuba"
  click_button "Search"
  click_link "Clear filters"
  expect(find_field("Manufacturer").value).to be_blank
end
```

## Carry state forward, don't reset between phases

You know what state the page is in after each click — write the next assertion against that state. Don't click a "Reset" / "Clear" between phases just to get a clean slate; resets cost a click (often two — clear, then re-establish), obscure what's actually happening, and tempt you to think of each phase as an isolated scenario rather than as one continuous user flow.

If a carried-over state makes the next assertion awkward, that's information: usually you can reorder or rephrase phases so the previous phase's end state is exactly what the next phase needs to start from. Treat the example as a flow with state advancing through it, not a sequence of independent scenarios each demanding a pristine baseline.

`visit page.current_url` is a reload, not a reset — use it specifically to verify URL persistence across a fresh page load. Otherwise, prefer letting state flow.

## Navigate by clicking, not re-visiting

After the initial `visit` in `before`, prefer **clicking** to get to the next state. Re-visiting bypasses the very thing system specs exist to verify (client-side state, JS handlers, history, ARIA wiring).

Re-visit only when you specifically want to verify **URL persistence / reload behavior** — and make that intent explicit (`visit page.current_url` with a comment, or a context named "after reload").

```ruby
# Good — drive the flow with clicks
visit "/search/marketplace"
fill_in "Manufacturer", with: "Yuba"
click_button "Search"

# Good — explicit reload to verify URL persistence
visit page.current_url

# Bad — re-rendering that should have been a click/form submit
visit "/search/marketplace?manufacturer=Yuba"
```

## Prefer named matchers over CSS selectors and JS

Capybara's high-level helpers find elements by visible role + text. They are more readable, more accessible (they only see what a real user can interact with), and less brittle than scraping selectors. Reach for low-level tools only when the high-level ones can't express what you need.

Order of preference:

1. **Named-element helpers**: `click_button("Search")`, `click_link("Next")`, `find_button(...)`, `have_button(...)`, `fill_in("Manufacturer", with: ...)`.
2. **Role-scoped Capybara finders**: `find(:button, "...")`, `within(:section, "Filters") { ... }`.
3. **ARIA / data attributes** when there is no visible text: `find('[aria-label="..."]')`, `find('[data-test-id="..."]')`.
4. **CSS selectors** as a last resort.
5. **`page.execute_script`** only when the browser fundamentally cannot otherwise do what the test needs (synthesizing custom events, scrolling for IntersectionObserver, etc.).

If a button has no visible text (icon-only, etc.), add an `aria-label` to the component rather than scraping a selector in the test.

### Good

```ruby
click_button("Search")
expect(find_button("Sort")["aria-pressed"]).to eq "true"
expect(page).to have_link("Next")
```

### Bad

```ruby
find('[data-action="click->search#submit"]').click
expect(page).to have_css('button[aria-pressed="true"]')
page.execute_script("document.querySelector('.search-btn').click()")
```

## ActionCable broadcasts: do the real thing

The test cable adapter is `:async`, so broadcasts in the test process do round-trip to the browser. **Don't synthesize `turbo:morph-element` events with `execute_script` to fake an ActionCable refresh** — call the real broadcaster (`Component.broadcast_replace_to`, `broadcast_refresh_later_to`, etc.) and let Capybara's wait do the synchronization.

The pattern is: prepare the data the broadcast will render → call the real broadcaster → assert on an unambiguous post-morph element with a `wait:` (e.g. `expect(page).to have_css(some_new_selector, wait: 5)`). The trailing wait is the synchronization barrier — the test proceeds only once the morph has actually rendered.

## Build Tailwind before running system specs

CI builds `app/assets/builds/tailwind.css` automatically; your local sandbox does not. Without it, Tailwind utility classes (most importantly `tw:hidden` → `display: none`) silently don't apply, and assertions like `expect(tooltip).not_to be_visible` fail in confusing ways that look like flakes but aren't.

**Before running any `:js, type: :system` spec locally, run `bin/rails tailwindcss:build`** (or have `bin/dev` running, which watches and rebuilds). If a system spec is failing on visibility/styling assertions, check `app/assets/builds/tailwind.css` exists and is recent before assuming the test or component is broken.

See the [`frontend-conventions`](../frontend-conventions/SKILL.md) skill for the `tw:` prefix and other styling rules.

## Other conventions

- Always include `:js, type: :system`.
- Define a few small DSL-style helpers in the file (`def listing_for(item)`, `def thumbnail_selector(...)`) when they make assertions readable. Don't reach for `page.execute_script` to replace what a helper method could do in Ruby.
