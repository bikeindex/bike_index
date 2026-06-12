# Accessibility issues

Findings from a code review of the frontend (views, ViewComponents, Stimulus controllers,
legacy CoffeeScript/jQuery, stylesheets), prompted by an external audit citing WCAG 2.1.1
Keyboard failures: donation amount buttons, carousel navigation, links on certain pages,
adding a bike / stolen bike / abandoned bike, the hamburger menu, and Bike Index statistics.

The root cause behind most 2.1.1 failures is the same pattern: **interactive controls built
from `<a>` tags without `href` (or `div`s) wired up with click-only handlers**. Anchors
without `href` are not in the tab order and never receive Enter-key activation, so these
controls are completely unreachable by keyboard.

Severity: **High** = control is unusable by keyboard or unusable with a screen reader on a
core user path. **Medium** = degraded but workable, or affects secondary pages.
**Low** = best-practice gap.

---

## 1. Donation amount buttons — High

The audit's "donation amounts buttons" finding.

- `app/views/shared/_donation_form.html.erb:29-48` — preset donation amounts ($5–$500) are
  `<a class="btn">` elements with **no `href`**, selected via a click-only handler in
  `app/assets/javascripts/revised/pages/info/payments.coffee:10`. Not focusable, not
  keyboard-operable. *(2.1.1)* Fix: use `<button type="button">`.
- `app/views/shared/_donation_form.html.erb:55-60` — the custom amount input
  (`#arbitrary-amount`) has only a placeholder; no `<label>` or `aria-label`. *(1.3.1, 3.3.2)*
- `app/views/shared/_donation_modal.html.erb:71-77` — the "skip donation" dismiss control is
  an `<a>` rather than a `<button>`. *(4.1.2)*
- `app/assets/stylesheets/og_application.scss:2604-2612` — `.btn.active` sets `outline: 0`
  with no replacement focus indicator, so the selected amount can't show keyboard focus.
  *(2.4.7)*

## 2. Carousels and landing pages — High

The audit's "carousel navigational elements" finding.

- `app/javascript/controllers/landing_pages/tabs_controller.js` — tab widget has no ARIA
  roles (`tablist`/`tab`/`tabpanel`), no `aria-selected`, and no arrow-key navigation.
  Markup in `app/components/page_block/landing_for_law_enforcement/component.html.erb:92-195`
  has the same gaps. *(2.1.1, 4.1.2)*
- `app/javascript/controllers/landing_pages/testimonials_controller.js:32-43` —
  `createDots()` builds `<button>` dots with no accessible name and no `aria-current`.
  *(4.1.2, 2.4.4)*
- Testimonials auto-advance every 8s with pause-on-hover only — no pause on focus, no
  visible pause control (`testimonials_controller.js:8-25`). *(2.2.2)*
- `app/assets/stylesheets/kelsey/landing_pages.css:161-176` — partners strip auto-scrolls
  via infinite CSS animation; pause is `:hover`-only, no keyboard or button control. *(2.2.2)*
- Carousel prev/next arrows have no accessible name (only `‹`/`›` glyphs):
  - `app/components/page_block/landing_for_law_enforcement/component.html.erb:251-266`
  - `app/components/page_block/landing_for_schools/component.html.erb:246-261`
  - `app/components/page_block/homepage_top/component.html.erb:124-139` and `189-204`
  *(4.1.2)*
- Kelsey stylesheets define `:hover` styles for buttons, arrows, and dots but **no
  `:focus`/`:focus-visible` styles** (`landing_pages.css:79-116, 521-556`,
  `homepage.css:467-483, 677-705`). *(2.4.7)*
- Hidden carousel slides stay in the DOM without `aria-hidden`
  (`homepage_top/component.html.erb:84-120`,
  `landing_for_law_enforcement/component.html.erb:231-248`). *(1.3.1)*
- Generic alt text: testimonial image hardcoded `alt="Bike Love"`
  (`homepage_top/component.html.erb:239`). *(1.1.1)*
- Dots are 10×10px, nav arrows 30×30px — below recommended target size
  (`landing_pages.css:546-556`, `homepage.css:467-483`). *(2.5.5, low priority)*

## 3. Hamburger menu and header navigation — High

The audit's "hamburger menu" finding.

- `app/views/layouts/application.html.erb:96-98` — the hamburger toggle is
  `<a id="primary_nav_hamburgler">` with no `href`, no `role`, no accessible name, inside a
  `div` marked `aria-hidden="true"`. Click handler only
  (`app/assets/javascripts/revised/sections/nav_header.coffee:25-51`): no Enter/Space/Escape
  support, no focus management, no `aria-expanded`. The mobile menu is completely
  inaccessible by keyboard and invisible to screen readers. *(2.1.1, 4.1.2)*
- `app/views/layouts/application.html.erb:94` — `<a id="menu-opened-backdrop">` is an empty
  href-less anchor used as the close-menu backdrop; there is no keyboard way to close the
  menu. *(2.1.1)*
- `app/views/layouts/application.html.erb:67-76, 113-120` — organization and settings
  dropdowns use `<a href="#" data-toggle="dropdown">` (legacy Bootstrap): no arrow-key
  navigation, no Escape-close, and the settings toggle is icon-only with no accessible name.
  *(2.1.1, 4.1.2)*
- `app/views/layouts/application.html.erb:80, 161` — `aria-labelledby="#passive_organization_submenu"`
  / `"#setting_submenu"`: ID references must not include the `#` prefix, so the labels are
  broken. *(4.1.2)*
- `app/assets/stylesheets/revised/sections/primary_header_nav.scss:232, 287-289` — the
  off-canvas menu is hidden by transform; menu links can remain reachable while invisible
  (focus disappears). Closed menus need `display: none`/`visibility: hidden` or
  `aria-hidden`. *(2.4.7, 2.4.3)*
- No skip-to-content link and no `<main>` landmark in `application.html.erb` (or
  `admin.html.erb`) — keyboard users must tab through the entire header on every page.
  *(2.4.1, 1.3.1)*
- `app/javascript/controllers/ui/dropdown_controller.js` (the modern replacement) handles
  Escape and click-outside but has no arrow-key navigation between items. *(2.1.1, partial)*
- `app/javascript/controllers/ui/modal_controller.js` / `app/views/shared/_modal.html.erb` —
  legacy modal has no `role="dialog"`, no `aria-modal`, no focus trap, no focus restore;
  Escape handling uses deprecated `keyCode`. *(2.4.3, 4.1.2)*
- `app/views/shared/_footer_revised.html.erb:5, 25, 38, 68, 135` — multiple `<nav>`
  landmarks with no distinguishing `aria-label`. *(1.3.1)*

## 4. Adding a bike / stolen bike / abandoned bike — High

The audit's "adding a bike, adding a stolen bike, adding an abandoned bike" finding.

- `app/views/welcome/choose_registration.html.erb:12-52` — the cards that choose
  registration type (normal / stolen / impounded-abandoned) are `<a>` tags with `data-target`
  and **no `href`**, driven by a click-only handler
  (`app/assets/javascripts/revised/pages/user/choose_registration.coffee:4`). A keyboard
  user cannot start any registration flow from this page. *(2.1.1)*
- `tabindex="-1"` on real form controls removes them from the tab order:
  - `app/views/bikes/new.html.erb:86` ("I don't know the serial") and `:166` ("unknown year")
  - `app/views/organizations/_embed_fields.html.erb:33, 76` (same controls in the embed form)
  - `app/views/bikes_edit/bike_details.html.haml:100`
  *(2.1.1)*
- `app/views/organizations/_embed_fields.html.erb:109-152` — form toggle links combine
  `href="#"` with `tabindex="-1"`, making them mouse-only. *(2.1.1)*
- `app/views/bikes_edit/bike_details.html.haml:131-143` +
  `app/assets/javascripts/revised/pages/bikes/edit_bike_details.coffee:49` — frame size and
  cm/in pickers are styled labels over radios hidden with `display: none` (not focusable),
  selection via click handler only. *(2.1.1, 1.3.1)*
- `app/views/bikes_edit/bike_details.html.haml:26-55` +
  `edit_bike_details.coffee:21` — version start/end date toggles are href-less anchors with
  click-only handlers. *(2.1.1)*
- `app/views/bikes_edit/_revised_colors.html.haml:16-37` — add/remove secondary/tertiary
  color (`+`/`–`) links are click-only. *(2.1.1)*
- `app/views/bikes/theft_alerts/new.html.haml:29, 71-72` +
  `app/assets/javascripts/revised/pages/bikes/edit_alert.coffee:9-12` — theft alert plan
  cards and image selection are divs with click handlers; no keyboard path to buy an alert.
  *(2.1.1, 4.1.2)*
- `app/views/bikes/new.html.erb:55-62` — `?` help popovers (`data-toggle="popover"`) are
  click/hover-only. *(2.1.1)*
- `app/views/bikes/new.html.erb:113-116` — motorized/propulsion toggle reveals fields via
  jQuery `.collapse()` with no `aria-expanded`/`aria-controls`. *(4.1.2)*
- `app/assets/javascripts/revised/pages/bikes/show.coffee` — bike photo gallery thumbnails
  (`.clickable-image`) are click-only. *(2.1.1)*
- `app/views/public_images/_public_image.html.haml:26` — photo remove control is icon-only
  with no accessible name. *(4.1.2)*
- `app/components/form/legacy_form_well/address_record/component.html.erb:85` — empty
  `<label class="form-well-label">` leaves city/postal fields unlabeled in some states.
  *(1.3.1, 3.3.2)*
- Fancy selects (selectize, `.fancy-select`) used throughout registration: selectize strips
  the focus outline (`documentation_v2.scss:1572`) and its keyboard behavior is unaudited.
  *(2.4.7, 2.1.1 — verify)*

## 5. Bike Index statistics ("where" / info pages) — Medium

The audit's "bike index statistics" finding.

- `app/views/info/where.html.haml:48, 85` — "show on map" shop-location links have no
  `href`; `app/views/shared/_shops_map.html.erb:43` later injects
  `href="javascript:clickLocation(i)"`. Brittle, and the controls do nothing without JS.
  *(2.1.1)* Fix: `<button>` with a data attribute.
- `app/views/shared/_shops_map.html.erb` — the Google Map (`#map_canvas`) has no accessible
  name or text alternative; the partner list below should be marked as the accessible
  equivalent. *(1.1.1)*
- Statistics counts/graphs on info pages have no text alternative where rendered as
  visuals. *(1.1.1 — verify per page)*

## 6. Site-wide patterns — Medium

- **`href="#"` used for button-like actions** (~74 instances, mostly admin and dropdown
  toggles, e.g. `app/views/admin/organizations/index.html.erb:7`,
  `app/components/org/bike_access_panel/component.html.erb:127`). Focusable but
  semantically wrong, and activating them scrolls to top. *(4.1.2)*
- **Anchors with no `href` as controls** beyond those listed above, e.g.
  `app/components/org/registration_search/component.html.erb:229`,
  `app/views/organizations/embed.html.erb:12, 18`. Not focusable at all. *(2.1.1)*
- **`outline: none` without replacement** in legacy stylesheets:
  `documentation_v2.scss:1572, 1839, 1945, 1953, 2060, 2071, 8657`,
  `og_application.scss:8817, 9641, 11930, 12522`, `bootstrap/_reboot.scss:88, 194`. *(2.4.7)*
- **`image_tag` without `alt`** (≈19 instances): header logos
  (`app/views/shared/_header_nav.html.erb:6-7`), reg-embed layout
  (`app/views/layouts/reg_embed.html.erb:21, 32`), email layout
  (`app/views/layouts/email.html.erb:40`), organization avatars
  (`_organized_skeleton.html.erb:7`, `_claim_message.html.erb:7`), FAQ search icon
  (`app/views/shared/_faq.html.erb:64`), dynamically inserted image in
  `app/views/public_images/create.js.erb:6`, plus admin views. *(1.1.1)*
- **Placeholder-only search inputs** (~20 admin/index forms): e.g.
  `app/views/admin/organizations/index.html.erb:82`,
  `app/views/admin/b_params/index.html.erb:56`,
  `app/views/doorkeeper/applications/admin_index.html.erb:8`. *(1.3.1, 3.3.2)*
- **`role="menu"` misuse** on the UI dropdown list
  (`app/components/ui/dropdown/component.html.erb:31`) — disclosure menus of links should
  not use the `menu` role unless full menu keyboard semantics are implemented. *(4.1.2)*
- **Status conveyed by color alone** in some admin tables/badges. *(1.4.1 — verify per view)*

---

## Suggested remediation order

1. **Unblock keyboard users on core paths** (all `<a>`-without-`href` controls → real
   `<button>`s; remove `tabindex="-1"` from form controls): donation amounts,
   choose-registration cards, hamburger menu, serial/year checkboxes, theft alert plans.
2. **Restore focus visibility**: remove/replace bare `outline: none`; add
   `:focus-visible` styles to kelsey buttons, arrows, dots.
3. **Disclosure semantics**: `aria-expanded`/`aria-controls` + Escape on hamburger and
   dropdowns; fix the two broken `aria-labelledby="#…"` references (one-line fixes).
4. **Carousels**: accessible names on arrows/dots, pause control for auto-advance,
   `aria-hidden` on inactive slides, tablist semantics for the landing page tabs.
5. **Structure & labels**: `<main>` + skip link in layouts, footer nav labels, alt text
   sweep, label the placeholder-only inputs.

Notes: the modern `ui/` Stimulus components (modal uses `<dialog>`, dropdown handles
Escape) are the right direction — migrating remaining legacy Bootstrap/CoffeeScript widgets
to them fixes several findings at once. Findings marked "verify" were identified from code
reading and should be confirmed in-browser (keyboard-only walkthrough + VoiceOver/NVDA).
