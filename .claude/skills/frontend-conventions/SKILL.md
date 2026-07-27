---
name: frontend-conventions
description: >-
  Bike Index's frontend conventions — Tailwind class prefixing (`tw:`),
  the standard `twinput`/`twlabel`/`twlink` form/link classes, the
  `number_display` helper for numbers, the UI component library rule
  (every button is `UI::Button`/`UI::ButtonLink`, every
  typeahead/autocomplete is `UI::Forms::Combobox`, never hand-rolled
  markup), ViewComponent rules (keyword arguments, instance variables,
  `helpers.` prefix in templates), and `UI::Time::Component` for every
  date/time. Trigger
  when adding or modifying views (`.html.erb`), view components, Stimulus
  controllers, Tailwind classes, or any frontend code that touches styling
  or interactivity. **Also trigger before any
  `mcp__playwright__browser_take_screenshot` call** — this skill defines
  the required `tmp/` filename rule so screenshots don't land in the
  project root. Stimulus.js is the JavaScript framework; SCSS and
  CoffeeScript files exist but are deprecated.
---

# Frontend conventions

This project uses **Stimulus.js** for JavaScript interactivity and **Tailwind CSS** for styling. There are SCSS styles and CoffeeScript files, but they are deprecated — don't add to them.

The `bin/dev` command handles building and updating Tailwind and JS.

**Format ERB before committing.** After editing any `.html.erb`, run `bin/lint <file>` — it runs `herb-format`, which sorts `tw:` classes and reflows long `class` attributes onto multiple lines. CI's `lint_and_scan` job runs `herb-format --check` as a step separate from `standardrb`/`rubocop`, so hand-edited ERB that skips formatting fails CI even when the Ruby is clean.

## Tailwind classes and helpers

- Tailwind classes have the prefix `tw:` (e.g. `tw:text-blue`, `tw:flex`, `tw:gap-4`).
  - The `tw:` prefix comes **before** variant modifiers, not after. Use `tw:dark:bg-gray-800`, `tw:hover:bg-blue-600`, `tw:sm:flex`, `tw:focus-visible:ring-2`. Never `dark:tw:bg-gray-800` — variant prefixes layer on top of `tw:`.
- Form fields should use the `twinput` class.
- Labels should use the `twlabel` class.
- Basic links should use the `twlink` class.
- **Every number** should be rendered with `number_display(number)`. This applies even when a number is composed into a string with non-numeric values — wrap the number itself, not the surrounding string.
  - Good: `[number_display(@bike.year), @bike.mnfg_name].join(" ")`
  - Bad: `[@bike.year, @bike.mnfg_name].join(" ")`
  - "Number" includes years, counts, prices, distances, IDs — anything numeric, even when it reads like a label.
- **Currency amounts** use `amount_display(obj)` instead of `number_display` directly. It takes an object that responds to `amount_cents`, `amount`, `currency_symbol`, and `currency_name` (e.g. a `MarketplaceListing`), and renders the symbol + `number_display(amount)` together. Don't reach for `number_to_currency` or roll your own.
- **Every date/time** renders through `UI::Time::Component` — `render(UI::Time::Component.new(time: some_time))`. It emits the client-localized `localizeTime` span the frontend JS converts to the viewer's timezone. This is the *only* way to show a time: never `l(time, ...)`, `strftime`, `time_ago_in_words`, or a hand-written `localizeTime` span. Pass `format: :localize_time_precise` when you need seconds precision (default is `:localize_time`). It self-hides when `time` is nil, so no surrounding `if` guard is needed.

## Buttons: always `UI::Button` (and the UI component library generally)

**Every button goes through `UI::Button::Component`** — never a hand-rolled `<button>`, `button_to`, or submit input with ad-hoc Tailwind classes. The component centralizes colors (`:primary`/`:secondary`/`:error`/`:link`), sizes (`:sm`/`:md`/`:lg`), and the focus/active/dark-mode states; a hand-styled button silently drifts from all of that the next time the design changes.

- Plain button or form submit: `render UI::Button::Component.new(text: "Save", color: :primary, kind: :submit)`.
- A link styled as a button: `UI::ButtonLink::Component.new(href:, text:, color:, size:)` — same palette, renders an `<a>`.
- A standalone action button (POST/DELETE/etc. to a URL) — a link that performs an action: pass `method:` to `ButtonLink` and it renders `button_to` for you (`render UI::ButtonLink::Component.new(text: "Delete", color: :error, href: bike_path(@bike), method: :delete)`), so don't hand-roll a `button_to` or wrap a submit button in a bare form. Extra `html_options` flow through: pass `params:` for a POST that carries params (they render as hidden fields — no manual `form_with`/`hidden_field_tag` needed), and `form: {onsubmit: …}` for a confirm on the wrapping form.

The same instinct applies beyond buttons: **check `app/components/ui/` before hand-rolling any UI primitive** (dropdowns → `UI::Dropdown`, tooltips → `UI::Tooltip`, form fields → `UI::Forms::*`, badges, modals, pagination, tables…). If a `UI::*` component exists for the pattern, use it; if it almost fits, extend it rather than forking its markup inline.

## Tooltips: default `?` button trigger

**Every `UI::Tooltip` uses the default `?` button trigger** unless the user explicitly says otherwise — never pass a label as the tooltip's trigger content. See `app/components/ui/tooltip/`.

## Form fields: the label comes from `UI::Forms::Group`

**A `UI::Forms::*` field renders no label of its own** — wrap it in a `UI::Forms::Group` with `kind: :content_block`, passing `form_builder:` when there is one. Holds for `Combobox`, `Select`, and `TextEditor`. See `app/components/ui/forms/group/component_preview/` and `app/components/ui/forms/combobox/component_preview/`.

## Typeaheads: always `UI::Forms::Combobox`

**Every typeahead / autocomplete / combobox goes through `UI::Forms::Combobox::Component`** — never a new Stimulus controller that fetches matches and renders its own menu. See `app/components/ui/forms/combobox/` (component + `component_preview.rb`) and `spec/components/ui/forms/combobox` for how to invoke it.

## Showing and hiding elements: always use the collapse helpers

Any time you show, hide, or toggle an element in response to interaction, go through the shared collapse helpers. **Never** hand-roll it with the `hidden` attribute, `element.style.display`, `element.hidden = true`, or ad-hoc `classList.add('tw:hidden')` — those skip the shared show/hide animation and the `tw:hidden!`/`tw:hidden` class contract the rest of the app depends on.

- **Markup-only toggle** (a trigger reveals/collapses a panel, no other logic): add `data-controller="collapse"`, mark the collapsible element `data-collapse-target="content"`, and wire the trigger's `data-action` to `collapse#toggle` / `collapse#show` / `collapse#hide` (`app/javascript/controllers/collapse_controller.js`; optional `data-collapse-duration-value`).
- **Inside your own Stimulus controller** (you have extra logic — a redirect branch, a query-param check, etc.): import `collapse_utils` and call it directly:

  ```js
  import { collapse } from 'utils/collapse_utils'
  // ...
  collapse('show', this.formTarget)   // 'show' | 'hide' | 'toggle'; optional duration (default 200)
  ```

The collapsible element starts hidden with the **`tw:hidden` class** (not the `hidden` attribute) — `collapse` toggles `tw:hidden`/`tw:hidden!` and runs the height/scale transition for you. Because the initial hidden state is a class, component specs assert it by class (`have_css("[…].tw\\:hidden")`), not Capybara visibility — the rack_test driver doesn't evaluate CSS, so it can't tell a class-hidden element is hidden.

## No dead hooks in markup

Only add an `id` or non-utility `class` when something concrete consumes it — a CSS rule, a JS/Stimulus selector, a test fixture, an accessibility attribute. Don't keep or invent "structural identifier" hooks "in case something needs them later," and don't replace a removed hook with a renamed one out of inertia.

When deleting an `id`/`class`, grep the repo for the name before deciding what to do with it:

- Zero consumers: delete it, don't rename it.
- Consumers exist: either update them, or leave the hook in place — the consumers are the *reason* it earns its spot in the markup.

## ViewComponent rules

This project uses the ViewComponent gem to render components.

- Prefer view components to partials.
- Generate a new view component with `rails generate component ComponentName argument1 argument2`.
- View components must initialize with keyword arguments. Everything the component needs must be passed in explicitly by the caller — never reach into controller state from inside a component (e.g. `controller.instance_variable_get(:@bike)`). If the component needs `@bike`, the caller renders `Component.new(bike: @bike)`.
- In view components, use instance variables directly — don't add `attr_reader`/`attr_accessor`. Reference `@foo` everywhere, including in the template (`@current_user`, not `current_user`).
- In ViewComponent templates, use the `helpers.` prefix for view helpers (e.g. `helpers.time_ago_in_words`).
  - Rule of thumb: try the bare call first. Only add `helpers.` if it fails with `NoMethodError` — route helpers (`new_bike_path`) and ActionView tag/url builders (`tag.span`, `content_tag`, `link_to`) are mixed into `ViewComponent::Base` directly, so they don't need it.
- **Never nest a component inside a folder that already holds a `component.rb`.** Each component lives in `app/components/<path>/component.rb` (and `spec/components/<path>/component_spec.rb`); siblings go in sibling folders, not subfolders. If you have `search/everything_combobox/component.rb` and need a related component, place it at `search/everything_combobox_options/component.rb` (module `Search::EverythingComboboxOptions`), not `search/everything_combobox/options/component.rb`.
- **Converting a partial to a component is a faithful move, not a cleanup.** Carry the markup over verbatim — including comments and commented-out code. Those lines are often a deliberate stash (a link that's temporarily disabled, a snippet someone expects to restore), so dropping them silently loses intent and surprises the reviewer, who expects the diff to read as "same content, new home." The only changes a conversion should introduce are the mechanical ones the move *requires*: `t(".x")` → `translation(".x")`, adding `helpers.` where a helper now needs it, and the like. If you spot something that genuinely looks like dead code worth removing, that's a separate judgment call — raise it with the user or do it in its own commit, don't fold it into the move.

## Playwright screenshot filenames

**Every `mcp__playwright__browser_take_screenshot` call must pass a `filename:` that starts with `tmp/`** (e.g. `tmp/tooltip-hover.png`). The MCP tool's default root is the project root — a bare filename like `tooltip.png` lands in the working tree, shows up in `git status`, and has to be cleaned up by hand. `tmp/` is gitignored, so screenshots there stay out of commits and don't pollute the diff. This rule applies to ad-hoc visual verification, not just PR-screenshot capture.
