---
name: integration-testing
description: >-
  Bike Index conventions for browser specs (`type: :system, :js`)
  — **drive every step through the real UI** (no FactoryBot or
  `execute_script` shortcuts to skip what a user would do), every
  example pays a browser boot cost so bias toward fewer, denser
  examples that walk through state via clicks, prefer named-element
  matchers over CSS selectors, and combine same-setup work into one
  `it` even when scenarios feel independent. **Consult this skill
  any time you create or modify a `:js, type: :system` spec** —
  that includes everything under `spec/integration/` AND component
  system specs at `spec/components/**/*_system_spec.rb`. Read
  alongside the `rspec-testing` skill for the project's general
  `context`/`let` style.
---

# Integration testing in Bike Index

Browser specs (`type: :system, :js`) live in two places: feature flows under `spec/integration/` and component-level interaction specs at `spec/components/**/*_system_spec.rb`. Both drive a real Chromium session through `capybara-playwright-driver` (`spec/support/capybara.rb`) and pay a browser boot cost per example, so the same conventions apply to both: optimize for fewer, denser examples and high-level Capybara helpers. Always tag new specs with `:js, type: :system`.

The general `context`/`let` style and "what to test" rules are in the [`rspec-testing`](../rspec-testing/SKILL.md) skill — the rules below extend it for the system-spec case.

## Always follow the real user path

If a user does it in the UI, the spec does it in the UI — every step, including setup. `FactoryBot.create(:bike, …)` to skip a complicated form turns the spec back into a model test and passes silently when the form is broken.

If the UI path is hard, that's a real signal — usually a production bug (stale asset cache, missing seed data, wrong API URL). Fix the root cause; don't `execute_script` or factory around it. When it's *intermittent* rather than hard, the same principle applies with sharper teeth — see [`fixing-flaky-failures`](../fixing-flaky-failures/SKILL.md), which owns flake diagnosis and the rule that coverage is never what gives way.

`form.requestSubmit()` and clicking the submit button aren't the same event either: Turbo re-enables the **submitter** when a submission finishes, so a programmatically submitted form has no button to re-enable and looks correctly disabled, while the same code under a real click leaves the button live. This bites hardest when *verifying* rather than setting up.

Legitimate exceptions: reference data that exists in production via migrations, admin accounts outside the user flow, and stubs for genuinely external services (third-party APIs, Stripe, geocoders).

A step the browser never performs — a server-to-server token exchange, a webhook callback — goes over real HTTP to Capybara's own server rather than through the page: `Net::HTTP.post_form(URI.join(Capybara.current_session.server.base_url, "/oauth/token"), params)`. VCR's `ignore_hosts` covers `localhost`, so it isn't blocked. `spec/integration/oauth_spec.rb` is the pattern.

## One `it` per setup; many assertions per `it`

The [`rspec-testing`](../rspec-testing/SKILL.md) skill's "One example per distinct setup" rule, with the browser boot cost on top: a long, sectioned-with-comments example pays one boot, four short examples pay four.

**Combine same-setup work, even when scenarios feel independent.** Before writing a new `describe`/`context`/`it`, read the existing file and find an example whose fixtures and initial `visit` match what you need — then append your clicks/assertions to it. It's tempting to leave a separate `it` for things that feel like different concerns ("button-state test", "filter-persistence test", "URL-param test", "mobile-layout test"). Don't. Failure attribution is fine — the failed line number tells you exactly which phase broke. Only add a new block when the setup genuinely differs.

## Measure before consolidating — a fixed sleep usually outweighs the boots

Browser boot is real, but it is rarely what makes a slow file slow. Time the file before
merging anything: a `wait_for_timeout`/`sleep` sized to cover the slowest case is typically
most of the runtime, and merging examples doesn't touch it. Consolidating the two
`ui/button*` specs saved ~2s of the 44s they took; replacing one 400ms
settle saved the other ~32s.

Wait on the condition instead, capped so a cancelled or infinite animation can't hang the
example. `settle_animations` in `spec/support/integration_spec_helpers.rb` is the one to reach for
when a measurement follows a state change — it awaits the element's own transitions and races
them against the cap as a ceiling. Prove the wait is load-bearing before trusting it — drop the
cap to 1ms and the assertions it protects should fail.

`element.evaluate_script` may return a Promise; the driver awaits it before handing back.

## A negative matcher can't wait for a state to settle

`have_no_css`/`have_no_link` match the instant the condition holds, so a state that arrives
*late* — a class an orphaned `setTimeout` re-adds — never gets asserted, and the example
passes against the bug it was written for. Wait on a positive signal the sequence drops last,
then assert the absence: `spec/integration/mobile_nav_menu_spec.rb` waits out
`nav.primary-header-nav.enabled` before asserting `menu-in` is gone.

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

Clicking a top-nav link by its label is ambiguous — the footer repeats Marketplace, Blog, Donate and most of the rest, so scope it: `within("#primary-main-menu") { click_link "Marketplace" }`. The navbar renders each of those twice more, mobile and desktop, but only one is visible at a given width, so that isn't what the `Ambiguous` names.

When repeated assertions get noisy, define small DSL-style helpers in the file (`def listing_for(item)`, `def thumbnail_selector(...)`) — they read better than scattered selectors and keep you out of `page.execute_script`. **Check `spec/support/integration_spec_helpers.rb` before writing one, and move it there once a second spec wants the same one.**

## Component system specs must assert accessibility

A component system spec (`spec/components/**/*_system_spec.rb`) exists to verify a component renders and behaves correctly in a real browser — and "correctly" includes being accessible. **Every component system spec must call `expect_axe_clean` at least once**, after the component has rendered (and after any state change that swaps in new markup — a new field, an opened menu, an added row). The axe audit catches missing accessible names, bad ARIA, and broken label associations that no CSS-selector assertion would.

Treat an axe failure as a real bug in the component, not noise to silence: fix the markup (add the `aria-label`, associate the `<label>`, correct the `role`) rather than narrowing the audit. The shared helper disables a handful of rules (`spec/support/axe.rb`) — preview artifacts plus colour contrast — so a remaining violation is almost always genuine.

```ruby
visit "/rails/view_components/ui/forms/text_editor/component/default"

expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10)
expect_axe_clean

# ...and again after anything that swaps in new markup - an opened menu, a cloned row
expect_axe_clean
```

## A preview is not the page

A preview renders the component alone, so everything the surrounding page
contributes is absent: `autofocus` on the form, sibling Stimulus controllers,
Turbo, the rest of the layout. Behaviour that depends on any of those can pass
against the preview while the real page stays broken — the preview spec isn't
wrong, it just can't see the condition.

The layout is `component_preview`, which loads Tailwind and the importmap but
**not** `application_revised` — no jQuery, no bootstrap — and includes the legacy
stylesheet only when the URL carries Lookbook's display option
(`?lookbook%5Bdisplay%5D%5Blegacy_stylesheet%5D=true`, see the
[`frontend-screenshots`](../frontend-screenshots/SKILL.md) skill). So anything
driven by legacy JS can't be exercised from a preview at all, and anything styled
by a legacy stylesheet renders unstyled without that parameter — which makes every
visibility and responsive assertion meaningless. Cover both on a real page.

A combobox fix keyed off the `focus` event passed
`spec/components/ui/forms/combobox/component_system_spec.rb` while step 1 of the
register flow was still mangling its manufacturer field: that form is
`autofocus`, so the input already held focus and the rider's entering click
brought no focus event to hang the selection on. Keep the preview spec for what
the component does on its own, and cover page-level behaviour in the flow's own
spec under `spec/integration/` — where the autofocus, the Turbo frame and the
other controllers are all present.

A component system spec drives the preview route, so **the preview template is
that spec's fixture** — editing one changes what the spec starts from. Making the
parking-notification preview open its panel on load broke
`spec/components/pages/registrations/show/org_top_actions/parking_notification_form/component_system_spec.rb`,
which asserts the submit is disabled before the accordion is touched; the failure
named the button, not the preview. Give the preview a param for the state the
spec needs (`ComponentPreview#default` takes `panel:`) rather than dropping the
assertion.

## ActionCable broadcasts: do the real thing

The test cable adapter is `:async`, so broadcasts in the test process do round-trip to the browser. **Don't synthesize `turbo:morph-element` events with `execute_script` to fake an ActionCable refresh** — call the real broadcaster (`Component.broadcast_replace_to`, `broadcast_refresh_later_to`, etc.) and let Capybara's wait do the synchronization.

The pattern is: prepare the data the broadcast will render → call the real broadcaster → assert on an unambiguous post-morph element with a `wait:` (e.g. `expect(page).to have_css(some_new_selector, wait: 5)`). The trailing wait is the synchronization barrier — the test proceeds only once the morph has actually rendered.

## Failing a request on purpose: Playwright routes

`page.driver.with_playwright_page { |pw| pw.route(pattern, handler) }` is how a spec makes the
server 429, 500 or hang for one request — the app never sees it, so nothing half-saves. Four
things that cost real time when they go wrong:

- **The handler runs on a Playwright thread, and a raising handler hangs the request.** Nothing
  fulfills or continues it, so the page just sits there and the failure surfaces a step later as
  a confusing "expected to find …". Keep handlers boring: no `Enumerator#next` (`[429, 500].cycle`
  raises `fiber called across threads`), nothing that assumes the RSpec thread. Derive what varies
  from state you can read, e.g. `failures.length.odd? ? 429 : 500`.
- **Every Rails form submission is a POST over the wire**, so the HTTP method can't tell `create`
  from `update` — Rails' `_method` override lives in the body, and a multipart body (any form with
  a file input) turns `Rack::Utils.parse_query(request.post_data)` into garbage. Key on the page the
  request came from instead: `request.headers["referer"]` carries the step in its query string.
- **Collect what you intercepted and assert on it at the end.** A list of the requests you failed,
  compared against the exact list you expected, is what proves each one was hit — and hit once.
  Without it a key collision quietly means half your interceptions never happened.
- **A client-side timer you lengthen outruns Capybara's default wait.** `default_max_wait_time` is
  2 seconds here, so a retry/debounce stretched to 3s needs an explicit `wait:` on the next
  assertion. Use `wait_for { ... }` (in `IntegrationSpecHelpers`) to block on something only the browser
  knows — a route handler's record of a request it answered — that no Capybara matcher can see.

## Build Tailwind before running system specs

Without a current `app/assets/builds/tailwind.css`, `tw:hidden` silently doesn't apply and visibility assertions fail in ways that read as flakes. `bin/setup` builds it; otherwise `bin/rails tailwindcss:build` (the [`sandbox-test-setup`](../sandbox-test-setup/SKILL.md) skill has the rest); see [`frontend-conventions`](../frontend-conventions/SKILL.md) for the `tw:` prefix.

