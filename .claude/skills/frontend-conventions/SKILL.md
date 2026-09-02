---
name: frontend-conventions
description: >-
  Bike Index's frontend conventions — Tailwind class prefixing (`tw:`),
  the standard `twinput`/`twlabel`/`twlink` form/link classes, the
  `number_display` helper for numbers, the UI component library rule
  (every button is `UI::Button`/`UI::ButtonLink`, every
  typeahead/autocomplete is `UI::Forms::Combobox`, never hand-rolled
  markup), that **helpers are deprecated — render a view component
  taking full keyword arguments instead of adding or extending one**,
  ViewComponent rules (keyword arguments, instance variables,
  `helpers.` prefix in templates), and `UI::Time::Component` for every
  date/time. Trigger
  when adding or modifying views (`.html.erb`), view components, Stimulus
  controllers, Tailwind classes, or any frontend code that touches styling
  or interactivity — including admin screens, whose unlayered legacy CSS and
  prebuilt jQuery bundle invert several of these rules. Stimulus.js is the
  JavaScript framework; SCSS and CoffeeScript files exist but are deprecated.
---

# Frontend conventions

This project uses **Stimulus.js** for JavaScript interactivity and **Tailwind CSS** for styling. There are SCSS styles and CoffeeScript files, but they are deprecated — don't add to them.

The `bin/dev` command handles building and updating Tailwind and JS.

**Format ERB before committing.** After editing any `.html.erb`, run `bin/lint` on the files or directories you changed — `bin/lint app/components/ui/table`. It runs `herb-lint` and `herb-format`, which sort `tw:` classes, reflow long `class` attributes onto multiple lines, and flag things like an `<input>` missing `autocomplete`. CI's `lint_and_scan` job runs both as steps separate from `standardrb`/`rubocop`, so hand-edited ERB that skips formatting fails CI even when the Ruby is clean.

Scope it rather than running bare `bin/lint`: a whole-repo run reformats files outside your change, and every file it rewrites that you've already read gets re-injected into context in full.

## Tailwind classes and helpers

- Tailwind classes have the prefix `tw:` (e.g. `tw:text-blue`, `tw:flex`, `tw:gap-4`).
  - The `tw:` prefix comes **before** variant modifiers, not after. Use `tw:dark:bg-gray-800`, `tw:hover:bg-blue-600`, `tw:sm:flex`, `tw:focus-visible:ring-2`. Never `dark:tw:bg-gray-800` — variant prefixes layer on top of `tw:`.
- Form fields should use the `twinput` class.
- Labels should use the `twlabel` class.
- Basic links should use the `twlink` class.
- A link that should take the color of the text around it — inside an alert, a colored `<small>`, the review-app banner — uses `twlink-underlined` instead. Never hand-roll `tw:text-inherit tw:underline`. Its color must come from an ancestor, not a `tw:text-*` on the link itself, which would outrank the class at every state.
- **A row of two things side by side uses `twfieldrow` or `twwiderow`**, not `tw:md:grid-cols-2`. `twfieldrow` is for fields that read as one control (a city and its state); `twwiderow` is for cards and sections. Both break on the row's own width rather than a viewport breakpoint, so a row nested in a narrow card breaks where it should. `UI::Card`'s `full_bleed:` is keyed to `twwiderow` by a container query, so it only bleeds inside one, and only once that row is single-column. All three are in `app/assets/tailwind/bike_index_components.css`.
- The default text color is `tw:twtext-color` (`tw:twtext-color!` to force it). It's an `@utility`, hence the `tw:` prefix — **any Bike Index class that something `@apply`s has to be an `@utility`**; v4's `@apply` rejects a `@layer components` class with "Cannot apply unknown utility class".
- **A custom `@utility` has no fixed rank against a core one it collides with** — Tailwind sorts custom and core utilities together, so `tw:twfullbleed` emits after `tw:border` while another pairing may go the other way. A hand-written `@layer utilities { }` block in `bike_index_components.css` *does* have a fixed rank: it emits after everything Tailwind generates, so it takes ties and needs no `@variant` or `!`. That's also how to define an unprefixed class name — `@utility` would force the `tw:` prefix. `.only-dev-visible` is the pattern for both. Grep `app/assets/builds/tailwind.css` for the two selectors when a collision matters.
- **A Tailwind class a Stimulus controller toggles is a literal in that controller**, not a `static classes` value the template has to carry — `ui/table_controller.js` toggling `tw:overflow-x-scroll` is the pattern, and there are ~40 of those against one `static classes`. Tailwind scans `app/javascript`, so the utility is generated either way; reach for `static classes` only when call sites need different classes.
- **Every number** should be rendered with `number_display(number)`. This applies even when a number is composed into a string with non-numeric values — wrap the number itself, not the surrounding string.
  - Good: `[number_display(@bike.year), @bike.mnfg_name].join(" ")`
  - Bad: `[@bike.year, @bike.mnfg_name].join(" ")`
  - "Number" includes years, counts, prices, distances, IDs — anything numeric, even when it reads like a label.
- **Currency amounts** use `amount_display(obj)` instead of `number_display` directly. It takes an object that responds to `amount_cents`, `amount`, `currency_symbol`, and `currency_name` (e.g. a `MarketplaceListing`), and renders the symbol + `number_display(amount)` together. Don't reach for `number_to_currency` or roll your own.
- **Every phone number** renders through `Atoms::Phone::Component` — never a hand-rolled `tel:` link or `number_to_phone`. It links by default; pass `skip_link: true` for plain text. See `app/components/atoms/phone/`. Non-markup callers that need the formatted string (a form field value, a translation interpolation) use `Phonifyer.display`.
- **Every date/time** renders through `UI::Time::Component` — `render(UI::Time::Component.new(time: some_time))`. It emits the client-localized `localizeTime` span the frontend JS converts to the viewer's timezone. This is the *only* way to show a time: never `l(time, ...)`, `strftime`, `time_ago_in_words`, or a hand-written `localizeTime` span. Pass `format: :localize_time_precise` when you need seconds precision (default is `:localize_time`). It self-hides when `time` is nil, so no surrounding `if` guard is needed.
  - Legacy `l(time, format: :convert_time)` inside a `localizeTime` span predates the component and is still all over the admin tables. Convert one to `UI::Time::Component` whenever you touch the line it's on — including when it's the body of a `link_to`.

**Building markup to pass into a component argument uses `capture`** — a component keyword like `UI::Alerts::Base`'s `header:` or `UI::Header`'s `text:` takes a string, so a heading that wraps a link or an `<em>` has to be captured first.

## A component dropped into legacy markup is styled on the component

Every legacy stylesheet wraps itself in `@layer legacy` (see `app/assets/stylesheets/legacy_includes/_css_layers.scss`), which sorts below tailwind's `components` and `utilities`. So a `UI::*` component rendered inside legacy-styled markup **wins over the surrounding stylesheet's rules for every property its own classes set** — `UI::Button`'s `tw:inline-flex`, `tw:p-0` and `twlink` beat `.primary-header-nav`'s `display`, `padding` and `color` no matter how specific those selectors are.

**Admin is the exception, and it inverts the rule.** `app/assets/stylesheets/admin.scss` imports `legacy_includes/admin_unvendored` *outside* its `@layer legacy` block, so those rules are unlayered and beat every tailwind utility whatever the specificity. On an admin page a utility that collides with one needs `!` — and without it the class is inert, not merely outranked: `tw:-mb-px` on `.nav-tabs` looked like it was doing the work `.nav { margin-bottom: 0 }` was actually overriding. Check `getComputedStyle` rather than assuming the class landed.

**`!important` reverses layer order**, so a legacy-layer `!important` beats a tailwind utility that isn't. A rule kept "just in case" in `revised.scss` is not inert — it is what paints. Delete the legacy rule rather than leaving it alongside; `revised.scss` is fully inside the layer, so the utility already wins without it. Only `admin_unvendored` genuinely needs an `!important` companion, because it is unlayered. `.only-dev-visible` (`app/assets/tailwind/bike_index_components.css`, plus the one surviving companion in `admin_unvendored.scss`) is the worked example.

## Two Tailwind v4 traps

- **A build that was right can go wrong under you.** Each workspace runs its own `tailwindcss:watch`, and one can overwrite `app/assets/builds/tailwind.css` with a scan from before your edit — so a rule you just wrote is served, then isn't. Before believing a CSS change doesn't work, count it in the build (`grep -o '<class>' app/assets/builds/tailwind.css | wc -l`, since the file is minified onto few lines) and check the built file's mtime against the source's. `bin/rails tailwindcss:build` restores it.
- **A grid item stretches to its row.** For a `<div>` that's invisible, but a bare `<table>` grid item spreads the extra height across its own rows, so two `table-list` panels side by side pull each other's rows tall. `tw:items-start` on the grid, or wrap the table in a `<div>`.

## Buttons: always `UI::Button` (and the UI component library generally)

**Every button goes through `UI::Button::Component`** — never a hand-rolled `<button>`, `button_to`, or submit input with ad-hoc Tailwind classes. The component centralizes colors (`:primary`/`:secondary`/`:error`/`:purple`/`:link` — its `COLORS` is the list of record), sizes (`:sm`/`:md`/`:lg`), and the focus/active/dark-mode states; a hand-styled button silently drifts from all of that the next time the design changes.

**An in-page action trigger that doesn't navigate is a `UI::Button`, not `link_to "#"`** — `.herb.yml` runs `html-anchor-require-href` over `app/components` only, so a component is caught and an `app/views` template isn't. `UI::Forms::NestedFields::Component`'s add trigger is the worked example.

- Plain button or form submit: `render UI::Button::Component.new(text: "Save", color: :primary, type: "submit")`. Pass a class as `html_class:` — the component builds its own, so a `class:` raises.
- A link styled as a button: `UI::ButtonLink::Component.new(href:, text:, color:, size:)` — same palette, renders an `<a>`.
- A standalone action button (POST/DELETE/etc. to a URL) — a link that performs an action: pass `method:` to `ButtonLink` and it renders `button_to` for you (`render UI::ButtonLink::Component.new(text: "Delete", color: :error, href: bike_path(@bike), method: :delete)`), so don't hand-roll a `button_to` or wrap a submit button in a bare form. Extra `html_options` flow through: pass `params:` for a POST that carries params (they render as hidden fields — no manual `form_with`/`hidden_field_tag` needed), and `form: {onsubmit: …}` for a confirm on the wrapping form.

  - **Not inside another form** — `button_to` renders a `<form>`, and the parser drops a nested one, hoisting its button and hidden inputs into the outer form. The button then submits *that* form, and the `form: {onsubmit: …}` confirm goes with the dropped tag. Nothing errors; it just does the wrong thing when clicked. On a page that is itself a form (the my_account edit templates, every `form_well`), pass `data: {method: :delete, confirm: "…"}` to `ButtonLink` instead — jquery_ujs handles it, and `my_accounts/_root.html.haml` has done it that way for years. `SharedBlocks::MyAccount::OrganizationRoles` is the worked example.

The same instinct applies beyond buttons: **check `app/components/ui/` and `app/components/atoms/` before hand-rolling any UI primitive** (dropdowns → `UI::Dropdown`, tooltips → `UI::Tooltip`, form fields → `UI::Forms::*`, badges, modals, pagination, tables…). If a component exists for the pattern, use it; if it almost fits, extend it rather than forking its markup inline.

Three of those carry a rule beyond "use the component":

- **`UI::Tooltip` keeps its default `?` button trigger** unless the user explicitly says otherwise — never pass a label as the trigger content.
- **A `UI::Forms::*` field renders no label of its own** — render it inside a `UI::Forms::Group` block, passing `form_builder:` when there is one. Holds for `Combobox`, `Select`, and `TextEditor`. A visually hidden label is the exception: `Group`'s label always carries a required/optional suffix, so use a bare `label_tag` with `twlabel tw:sr-only`, the way `Pages::Search::Form` does.
- **Every typeahead / autocomplete goes through `UI::Forms::Combobox::Component`** — never a new Stimulus controller that fetches matches and renders its own menu. `spec/components/ui/forms/combobox` shows how to invoke it.

`Atoms::*` (`app/components/atoms/`) holds the small value-rendering components — `Atoms::Serial`, `Atoms::Sticker`, `Atoms::ShortId`, `Atoms::Phone`. Everything else is `UI::*`; older value renderers like `UI::AddressDisplay` predate the split and stay put. Render a serial with `Atoms::Serial::Component`, not `BikeHelper#render_serial_display`.

## Form drafts: always `form-persist`

**A form worth not retyping mirrors itself to localStorage through the `form-persist` controller** — never one of your own. It takes a `data-form-persist-key-value` unique per record, since the derived key is the form's action. See `app/components/pages/register/step1/component.rb` and `app/components/pages/register/step2/component.html.erb`.

**A controller whose UI hangs off a restored field reconciles in two places** — a `form-persist:restored@window->…` entry in the element's `data-action`, and the same call in its own `connect`. A hand-rolled `window.addEventListener` is the older idiom; don't add more. See `app/components/pages/register/step1/component.html.erb` with `app/javascript/controllers/register/heading_controller.js`.

## Current-page links: always `UI::ActiveLink`

**Every link that goes `aria-current` on the page it points at goes through `UI::ActiveLink::Component`** — never `current_page?` in a template, and never a Stimulus controller of your own comparing `window.location`. It always derives the state in the browser (`app/javascript/controllers/ui/active_link_controller.js`), so there's no way to pass the answer in: `match:` is the only control over what counts as the page it points at. Any layout rendering one opens its `<body>` with `body_tag`. See `app/components/ui/active_link/`.

With `match: :query`, **`query:` is the params the entry stands for, not the ones its `path:` sets** — a filter entry that toggles links *away* from itself to clear the filter, so the two differ. Passing `path:`'s value to both fails silently, and only on the entry that is currently applied.

## Showing and hiding elements: always use the collapse helpers

Any time you show, hide, or toggle an element in response to interaction, go through the shared collapse helpers. **Never** hand-roll it with the `hidden` attribute, `element.style.display`, `element.hidden = true`, or ad-hoc `classList.add('tw:hidden')` — those skip the shared show/hide animation and the `tw:hidden!`/`tw:hidden` class contract the rest of the app depends on.

- **Markup-only toggle** (a trigger reveals/collapses a panel, no other logic): add `data-controller="ui--collapse"`, mark the collapsible element `data-ui--collapse-target="content"`, and wire the trigger's `data-action` to `ui--collapse#toggle` / `ui--collapse#show` / `ui--collapse#hide` (`app/javascript/controllers/ui/collapse_controller.js`).
- **Inside your own Stimulus controller** (you have extra logic — a redirect branch, a query-param check, etc.): import `collapse_utils` and call it directly:

  ```js
  import { collapse } from 'utils/collapse_utils'
  // ...
  collapse('show', this.formTarget)   // 'show' | 'hide' | 'toggle'; optional duration (default 200)
  ```

The collapsible element starts hidden with the **`tw:hidden` class** (not the `hidden` attribute) — `collapse` toggles `tw:hidden`/`tw:hidden!` and runs the height/scale transition for you. Use **`tw:hidden!`** when the element also carries a display utility that sorts after `hidden` — any `inline-*`, which every `UI::Button` has — and on an admin page whenever the element carries a legacy class that sets `display` (`.row` and `.card` are the ones that come up), for the unlayered reason above. A plain `tw:hidden` renders that panel open, and no component spec can see it: the class is in the attribute, it just loses the cascade. Because the initial hidden state is a class, component specs assert it by class (`have_css("[…].tw\\:hidden")`), not Capybara visibility — the rack_test driver doesn't evaluate CSS, so it can't tell a class-hidden element is hidden.

## No dead hooks in markup

Only add an `id` or non-utility `class` when something concrete consumes it — a CSS rule, a JS/Stimulus selector, a test fixture, an accessibility attribute. Don't keep or invent "structural identifier" hooks "in case something needs them later," and don't replace a removed hook with a renamed one out of inertia.

When deleting an `id`/`class`, grep the repo for the name before deciding what to do with it:

**On admin, grep `public/vendored_assets/*.js` as well as `app/`.** `application_standalone.js` still binds
behaviour by id and class, and its source left the repo with the webpack config, so it can't be rebuilt or
searched from source — a hook with no consumer in `app/` is routinely live. Its handlers are guarded on a hook being present — minified, so grep the id itself rather than
`$(`— and the guard is often a *different* id than the one bound: `#blog-image-form` gates the module
that binds `#infoCheck`. So removing an id silently disables behaviour, sometimes behaviour attached
to another id entirely.

- Zero consumers: delete it, don't rename it.
- Consumers exist: either update them, or leave the hook in place — the consumers are the *reason* it earns its spot in the markup.

## Helpers are deprecated — render a view component instead

**Never add a helper method, and don't extend an existing one.** Anything a helper would render belongs in a view component that takes what it needs as explicit keyword arguments. `app/helpers/` is legacy: leave what's there, but move a helper into a component when you touch the line that calls it.

- A *view helper* that only gathers a component's arguments out of controller assigns is still a helper — pass those arguments from the view.
- `ApplicationComponentHelper` is the exception (`number_display`, `amount_display`, `check_mark`, `search_emoji`) — value formatters `ApplicationComponent` already includes, so components call them bare.

**What's banned is the component reaching out, not the number of arguments.** State the controller already owns can be named and passed as one value object — `ComponentStructs::IndexState` (built in `ControllerHelpers#admin_index_state`) and `ComponentStructs::SortState` (`ControllerHelpers#sort_state`) are the pattern — value objects live in `app/services/component_structs/`. The component stays pure either way; a bundle just stops seventy views from re-listing the same seventeen assigns.

Bundle only what's cohesive — one subject, assembled in one place. `IndexState` is "this admin index request"; `ComponentStructs::SortState` is "how this table is sorted and what its links carry". A grab-bag of unrelated request facts (`display_dev_info`, `current_user`, `current_country_id`) is not a value object, it's `helpers` renamed — those stay individual arguments.

## ViewComponent rules

This project uses the ViewComponent gem to render components.

- Prefer view components to partials.
- **If a view file only renders a single component, consider rendering it from the controller instead** (`render Foo::Component.new(...)`) and deleting the view file — the layout still wraps it.
- Generate a new view component with `rails generate component ComponentName argument1 argument2`.
- View components must initialize with keyword arguments. Everything the component needs must be passed in explicitly by the caller — never reach into controller state from inside a component (e.g. `controller.instance_variable_get(:@bike)`). If the component needs `@bike`, the caller renders `Component.new(bike: @bike)`.
- In view components, use instance variables directly — don't add `attr_reader`/`attr_accessor`. Reference `@foo` everywhere, including in the template (`@current_user`, not `current_user`).
- In ViewComponent templates, use the `helpers.` prefix for view helpers (e.g. `helpers.time_ago_in_words`) — a legacy bridge, and a sign the helper wants to be a component.
  - Rule of thumb: try the bare call first. Only add `helpers.` if it fails with `NoMethodError` — route helpers (`new_bike_path`) and ActionView tag/url builders (`tag.span`, `content_tag`, `link_to`) are mixed into `ViewComponent::Base` directly, so they don't need it.
- **Never nest a component inside a folder that already holds a `component.rb`.** Each component lives in `app/components/<path>/component.rb` (and `spec/components/<path>/component_spec.rb`); siblings go in sibling folders, not subfolders. If you have `pages/search/everything_combobox/component.rb` and need a related component, place it at `pages/search/everything_combobox_options/component.rb` (module `Pages::Search::EverythingComboboxOptions`), not `pages/search/everything_combobox/options/component.rb`.
- **Run `bin/update_component_digests` after editing markup that a cached component renders**, rather than computing a digest by hand. Components with a `MARKUP_DIGEST` (`SharedBlocks::Footer`, `SharedBlocks::Navbar::Wrapper`) fold it into their fragment cache key, and it follows `render X::Component` transitively — so editing any component they render, however far down, moves theirs too. It hashes each of those components' *paths* alongside their contents, so moving or renaming one stales every digest above it even though the markup is byte-identical. The `cached_markup_digest` shared example is what catches a stale one.
- **Change a component's signature, then open its `component_preview.rb`** — nothing renders previews in the suite, so a stale one raises `ArgumentError: unknown keyword` on its Lookbook page with the whole suite green. `curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/rails/view_components/<path>/component/<scenario>"` is the check.
- **A `UI::Table` cell block is `instance_exec`'d against the component.** Inside `table.column ... do`, bare calls and `@ivar`s resolve on `UI::Table::Component`, not the view. A bare call raises, but **an `@ivar` fails silently** — it reads `nil`, or worse, an identically-named ivar the table happens to hold. Reach state through the readers the table exposes (`sort_state.search_params`, not `sortable_search_params`), and for anything else assign a local above the block, the way `Pages::Org::ImpoundRecordsTable` carries `current_organization` and `current_user`. Above the `UI::Table::Component.new` block the view's own helpers work; rewriting those too is churn.
- **A component that `include`s a helper is coupled to whatever ivars that helper reads.** `GraphingHelper#humanized_time_range` reads `@period` off the object it's mixed into, so moving that ivar out of the component silently returns nil rather than failing. Pass the value as an argument when converting a component to explicit arguments.
- **Moving a view into a component turns its locals into methods.** A `<% x = … %>` computed once per template becomes a method run once per *call site* — which is how a single pluck becomes one per table row. Memoize anything that queries as you move it.
- **Converting a partial — to a component, or from haml to ERB — is a faithful move, not a cleanup.** Carry the markup over verbatim — including comments and commented-out code. Those lines are often a deliberate stash (a link that's temporarily disabled, a snippet someone expects to restore), so dropping them silently loses intent and surprises the reviewer, who expects the diff to read as "same content, new home." The only changes a conversion should introduce are the mechanical ones the move *requires*: `t(".x")` → `translation(".x")`, adding `helpers.` where a helper now needs it, and the like. If you spot something that genuinely looks like dead code worth removing, that's a separate judgment call — raise it with the user or do it in its own commit, don't fold it into the move.

## Turbo is opt-in, and opting a form in has two consequences

`application.js` sets `Turbo.session.drive = false`, so links and forms submit natively
until something carries `data-turbo="true"`. Two things bite the first time a form opts
in, neither of which shows up as an error — the page just behaves oddly:

- **A controller-rendered component takes its content type from the request.** A Turbo
  submission sends `Accept: text/vnd.turbo-stream.html` first, and `render Foo::Component.new(...)`
  has no template format to override it, so the response comes back as a *stream message* —
  which Turbo appends to the current page instead of replacing it. Two steps of a wizard end
  up on screen at once. Fix it at the controller with `before_action { request.format = :html }`
  for actions that only ever render pages. (An `.html.erb` view doesn't have this problem: the
  template's own format sets the content type.)
- **`data-turbo="true"` on a form opts in every link inside it too** — navigability is
  resolved with `closest("[data-turbo]")`, so it isn't scoped to the submission. A link that
  leaves for a legacy jQuery page needs `data: {turbo: false}`, or it gets Turbo-rendered into
  a body whose `loadPageScript` never runs. Links to pages the Stimulus redesign owns are fine.
- **`data-turbo` is opt-*out* on any value but `"false"`** — an empty `data-turbo=""`, from
  interpolating a false into the attribute, reads as opted in. Render the attribute
  conditionally (`tag.attributes(data: {turbo: (true if @turbo)})`) rather than its value;
  `UI::Tabs` is the example.
- **Turbo restores its own snapshot on back/forward**, which `Cache-Control: no-store` can't
  reach. If what a page renders depends on server state, opt out with
  `helpers.content_for(:header) { tag.meta(name: "turbo-cache-control", content: "no-cache") }`
  — `Pages::Register::Page` and `Pages::SearchResults::Frame` are the examples — and a restoration re-fetches
  instead of showing a page the user has moved past.

`RegisterController` and the `Register::` components are the worked example of both.

## Admin screens

A record with more than one super-admin page gets `Pages::Admin::Headers::Tabs::Component`, with the
section's own tabs named in a component of their own — `Pages::Admin::Organizations::Tabs` is the
pattern — rather than restated in each view.

`sortable_search_params` (defined in the binxtils gem, `Binxtils::SortableHelper`) permits every
param starting with `search_`, plus the sort and period keys — which is how a filter link keeps the
rest of the table's state. Reach it through the reader, not the bare helper:
`url_for(@index.sortable_search_params.merge(search_kind: "x"))`.

### Admin pages that carry legacy JS can't be Turbo-visited

`application_standalone.js` is a plain `<script src>` in the admin layout, and everything it
sets up binds once inside one `$(document).ready` gated on `#admin-content` — the per-page
select, the selectize filters, the nested location fields, the uppy uploader. Turbo Drive
doesn't re-execute an unchanged script tag, and a back/forward restoration hands back a
*clone* of its snapshot, so that markup comes back looking live with nothing bound to it.

Two things follow. `turbo-cache-control` doesn't help — a restoration that re-fetches still
renders through Drive, and the admin layout doesn't yield `:header` to set it with anyway.
And it's the page you navigate *away from* that breaks, not just the one you land on.

So a screen carrying any of it passes `turbo: false` — `Pages::Admin::Headers::Tabs` takes it, and
`Pages::Admin::Organizations::CustomLayouts::Form::Wrapper` is the one that does. Before opting a new section in,
check its tab targets for `#per_page_select`, `.fancy-select`, `.add_fields`,
`#multipleUserSelect` and `.UppyForm`.

## Screenshots

Not this skill's — `frontend-screenshots` owns them, including where the files land.
