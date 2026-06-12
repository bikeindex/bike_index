# Accessibility issues

Two sources, combined:

1. **An external VPAT® 2.5Rev (WCAG edition) conformance report** dated August 24, 2025
   ("Bike Index webapp (bikeindex.org)", contact: Gavin Hoover), evaluating WCAG 2.1
   Levels A and AA. Summarized in full below.
2. **A code review of the frontend** (views, ViewComponents, Stimulus controllers, legacy
   CoffeeScript/jQuery, stylesheets) prompted by that report's 2.1.1 Keyboard finding,
   tying the reported failures to specific files and lines (sections 1–6).

The root cause behind most 2.1.1 failures is the same pattern: **interactive controls built
from `<a>` tags without `href` (or `div`s) wired up with click-only handlers**. Anchors
without `href` are not in the tab order and never receive Enter-key activation, so these
controls are completely unreachable by keyboard.

Severity: **High** = control is unusable by keyboard or unusable with a screen reader on a
core user path. **Medium** = degraded but workable, or affects secondary pages.
**Low** = best-practice gap.

**Status**: the keyboard-blocking and labeling issues below are fixed on this branch —
donation amounts are real buttons, choose-registration cards are real links, the
hamburger is a button with `aria-expanded`/Escape support, the `tabindex="-1"`s and
popover/modal triggers in the bike forms are keyboard-operable, the landing-page tabs
implement the ARIA tabs pattern with arrow keys, carousel arrows/dots have accessible
names and pause on focus/reduced-motion, the layout has a skip link and `<main>`
landmark, footer navs are labeled, the broken `aria-labelledby` references are fixed,
zoom is re-enabled everywhere, and the listed missing `alt`s are filled in. Still open:
the site-wide sweeps (heading hierarchy, color contrast, admin table header
associations, placeholder-only admin inputs, remaining `href="#"` pseudo-buttons,
selectize keyboard audit) and the legacy Bootstrap dropdown/modal focus management.

---

## VPAT conformance report (August 2025)

**Evaluation methods**: paired manual testing (one non-sighted tester, one sighted
accessibility expert) plus automated tools. Assistive tech: NVDA, JAWS, VoiceOver,
TalkBack, keyboard-only interaction, browser zoom. Tools: aXe, Color Contrast Analyzer.
Browsers: Chrome, Edge, Safari, Firefox on Windows 10, Mac, Android, iPhone.

**Overall verdict**: "partially supportive" of WCAG 2.1 AA. Summary issues called out:
heading structures, message notifications, insufficient color contrast, elements not
keyboard accessible, incorrect element roles, and focus order. Level AAA was not
evaluated.

Conformance terms: *Supports* = meets the criterion without known defects;
*Partially Supports* = some functionality does not meet it; *Not Applicable* = not
relevant to the product. Some remarks below are truncated in the source PDF (the table
runs off the page edge); truncations are marked with “…”.

### Level A

| Criterion | Conformance | Remarks (from the report) |
| --- | --- | --- |
| 1.1.1 Non-text Content | Partially Supports | Alt text missing on some images: footer, blog section images, bike images in Search. All linked images must have alternative text. |
| 1.2.1–1.2.3 (audio/video) | Not Applicable | No prerecorded audio/video content. |
| 1.3.1 Info and Relationships | Partially Supports | Heading hierarchy incorrect on some pages; `<li>` elements not wrapped in `<ul>`/`<ol>`; tables where reading down a column doesn't convey its relationship to related columns; data cells not explicitly associated with header cells; some form elements lack labels; form elements not grouped and ARIA not used to describe relationships between them. |
| 1.3.2 Meaningful Sequence | Supports | |
| 1.3.3 Sensory Characteristics | Not Applicable | |
| 1.4.1 Use of Color | Partially Supports | Some links have no styling (e.g. underline) to distinguish them from surrounding text. |
| 1.4.2 Audio Control | Not Applicable | |
| 2.1.1 Keyboard | Partially Supports | Most interaction is keyboard accessible, with exceptions: donation amounts buttons, carousel navigational elements, links on certain pages, adding a bike, adding a stolen bike, adding an abandoned bike, hamburger menu, bike index statistics, etc. |
| 2.1.2 No Keyboard Trap | Supports | |
| 2.1.4 Character Key Shortcuts | Supports | |
| 2.2.1 Timing Adjustable | Not Applicable | |
| 2.2.2 Pause, Stop, Hide | Not Applicable | (Disputed — see "Discrepancies" below.) |
| 2.3.1 Three Flashes or Below | Supports | |
| 2.4.1 Bypass Blocks | Supports | Headings/landmarks allow skipping repeated content; a skip-to-main-content link suggested as best practice. |
| 2.4.2 Page Titled | Supports | |
| 2.4.3 Focus Order | Partially Supports | Tabbing through main navigation doesn't move in a logical left-to-right order; screen reader focus doesn't move automatically to the first invalid input field in forms; Tab focus doesn't move to the first visible carousel slide and then to the carousel controls; screen reader doesn't read tables in the correct order. |
| 2.4.4 Link Purpose (In Context) | Partially Supports | Some links have no discernible text; some buttons don't have a value. |
| 2.5.1 Pointer Gestures | Supports | |
| 2.5.2 Pointer Cancellation | Supports | |
| 2.5.3 Label in Name | Partially Supports | Remarks discuss `lang` handling (see 3.1.1) — `lang="en"` on all pages except Documentation pages; Dutch/Norwegian versions toggle the lang attribute correctly. |
| 2.5.4 Motion Actuation | Partially Supports | (No remarks given.) |
| 3.1.1 Language of Page | Partially Supports | (No remarks given; per 2.5.3's remarks, Documentation pages are missing the `lang` attribute.) |
| 3.2.1 On Focus | Supports | |
| 3.2.2 On Input | Supports | |
| 3.2.6 Consistent Help (2.2) | Partially Supports | (No remarks given.) |
| 3.3.1 Error Identification | Supports | |
| 3.3.2 Labels or Instructions | Partially Supports | Mandatory form fields not announced as required by the screen reader; some form fields are missing labels. |
| 3.3.7 Redundant Entry (2.2) | Supports | |
| 4.1.1 Parsing | Supports | Always "Supports" per the September 2023 errata. |
| 4.1.2 Name, Role, Value | Partially Supports | Incorrect role defined on some elements; expanded/collapsed state not defined for accordions; error messages not automatically announced by the screen reader; some elements have no name; current-page status of the active link not defined; all accordions have an incorrect role of link; iframe elements have no accessible name. |

### Level AA

| Criterion | Conformance | Remarks (from the report) |
| --- | --- | --- |
| 1.2.4–1.2.5 (media) | Not Applicable | |
| 1.3.4 Orientation | Supports | |
| 1.3.5 Identify Input Purpose | Supports | |
| 1.4.3 Contrast (Minimum) | Partially Supports | Color contrast ratio of some elements is less than the standard… (truncated; flagged in the report's summary as "insufficient color contrast"). |
| 1.4.4 Resize Text | Partially Supports | "Zooming and scaling is disabled…" (truncated — likely a `user-scalable=no`/`maximum-scale` viewport meta). |
| 1.4.5 Images of Text | Partially Supports | Several violations: unscalable images of text impacting users with visual impairments…; text should be used to convey information rather than images of text. |
| 1.4.10 Reflow | Supports | |
| 1.4.11 Non-text Contrast | Supports | |
| 1.4.12 Text Spacing | Supports | |
| 1.4.13 Content on Hover or Focus | Supports | |
| 2.4.5 Multiple Ways | Supports | |
| 2.4.6 Headings and Labels | Partially Supports | Exceptions: heading levels…, tables not tagged properly…, (elements) not having labels (truncated). |
| 2.4.7 Focus Visible | Supports | (Disputed — see "Discrepancies" below.) |
| 2.4.11 Focus Not Obscured (2.2) | Supports | |
| 2.5.7 Dragging Movements (2.2) | Supports | |
| 2.5.8 Target Size Minimum (2.2) | Supports | |
| 3.1.2 Language of Parts | Supports | |
| 3.2.3 Consistent Navigation | Supports | |
| 3.2.4 Consistent Identification | Supports | |
| 3.3.3 Error Suggestion | Supports | |
| 3.3.4 Error Prevention (Legal, Financial, Data) | Not Applicable | App has no forms where legal/financial commitments require a review step. |
| 3.3.8 Accessible Authentication (2.2) | Supports | |
| 4.1.3 Status Messages | Supports | |

### Issues from the VPAT not yet tied to code

These appear in the report but weren't located in the code review above — each needs a
code-level investigation:

- **Heading hierarchy incorrect on some pages**; skipped heading levels. *(1.3.1, 2.4.6)*
- **`<li>` elements outside `<ul>`/`<ol>` parents.** *(1.3.1)*
- **Data tables without header associations** — data cells not tied to header cells
  (`<th scope>` / `headers`), columns unreadable down-column with a screen reader.
  *(1.3.1)* Likely candidates: admin tables and `UI::Table` components.
- **Links distinguishable by color alone** (no underline). *(1.4.1)*
- **Required fields not announced** — mandatory inputs lack `required`/`aria-required`.
  *(3.3.2)*
- **Error messages not announced** — validation errors need `role="alert"`/`aria-live`
  and focus should move to the first invalid field. *(4.1.2, 2.4.3, 3.3.1)*
- **Accordions with role of link and no expanded/collapsed state** — need
  `aria-expanded` on a `<button>` trigger. *(4.1.2)* Consistent with the disclosure
  toggles in sections 3–4 above.
- **iframes without accessible names** (`title` attribute). *(4.1.2)*
- **No `aria-current="page"` on active nav links.** *(4.1.2)*
- **Main navigation focus order not logical left-to-right.** *(2.4.3)*
- **Carousel focus order** — focus should go to the visible slide, then the controls.
  *(2.4.3)* Complements the carousel findings in section 2.
- **Insufficient color contrast on some elements.** *(1.4.3)* Needs an aXe/Color
  Contrast Analyzer pass per page.
- **Zooming/scaling disabled.** *(1.4.4)* Check layouts for viewport meta tags with
  `user-scalable=no` or `maximum-scale=1`.
- **Images of text** that don't scale. *(1.4.5)*
- **`lang` attribute missing on Documentation pages** (API docs layout). *(3.1.1)*
- **Motion actuation** — flagged Partially Supports with no detail. *(2.5.4)*
- **Consistent help** placement — flagged Partially Supports with no detail. *(3.2.6)*

### Discrepancies between the VPAT and the code review

Places where the report's conformance level looks too generous given what's in the code —
worth re-testing rather than trusting either source outright:

- **2.2.2 Pause, Stop, Hide — VPAT says Not Applicable**, but the homepage testimonials
  auto-advance every 8s and the partners strip auto-scrolls infinitely (section 2).
  Auto-updating moving content makes this criterion applicable, and it currently fails.
- **2.4.7 Focus Visible — VPAT says Supports**, but legacy stylesheets remove outlines
  without replacement and the kelsey landing-page controls have no `:focus` styles at
  all (sections 2 and 6).
- **2.4.1 Bypass Blocks — VPAT says Supports** (via headings/landmarks), but the main
  layouts have no `<main>` landmark (section 3), which weakens that pass; the suggested
  skip link is still worth adding.
- **2.1.2 No Keyboard Trap — VPAT says Supports**: technically true, but largely because
  the inaccessible controls (section 1, 3, 4) never receive focus in the first place.

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
6. **VPAT-only items**: re-enable pinch zoom if a viewport meta disables it (one-line
   fix), `aria-required` on mandatory fields, `role="alert"` on validation errors +
   focus the first invalid field, table header associations, heading-hierarchy and
   contrast sweeps, `lang` on the docs layout, `aria-current` on active nav links,
   `title` on iframes.

Notes: the modern `ui/` Stimulus components (modal uses `<dialog>`, dropdown handles
Escape) are the right direction — migrating remaining legacy Bootstrap/CoffeeScript widgets
to them fixes several findings at once. Findings marked "verify" were identified from code
reading and should be confirmed in-browser (keyboard-only walkthrough + VoiceOver/NVDA).
