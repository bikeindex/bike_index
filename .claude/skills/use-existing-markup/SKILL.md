---
name: use-existing-markup
description: >-
  Convert a branch's hand-written markup to the components that already render it.
  Covers marketing and landing pages on `SharedBlocks::Marketing` and the donate form,
  `UI::*` and `Atoms::*` everywhere else, icons and images the repo already has, buttons snapped to
  existing colors, shadows, and hover states to report. Trigger when a branch adds or
  redesigns a page's markup, especially a marketing, landing, donate or "how it works"
  page or a design handoff built from a mockup. Also trigger on "use existing
  components", "reuse the markup", "is this hand-rolled", and from the `pr` skill's
  markup audit. It replaces without asking.
---

# Use existing markup

## Who runs this

From a session with history, hand this skill to a subagent the way `AGENTS.md`'s **Who runs this** describes. Use no `model` override, because matching markup to a component is judgment. Brief it with the base branch, what the page is for, and any design choices the user already made. It replies with the four lists under **The reply**, with the conversions left uncommitted in the working tree.

## Find what the branch adds

```bash
rtk proxy git diff origin/main...HEAD -U0 -- '*.erb' '*.haml' 'app/components/*.rb' |
  grep -E '^(\+\+\+ |\+\s*%[a-z]|\+.*(<[a-z]|link_to|button_to|content_tag|tag\.|tw:|inline_svg_tag|image_tag))'
rtk proxy git diff origin/main...HEAD --name-only --diff-filter=A -- app/assets/images app/components
```

Nearly every template line matches `tw:`, so treat the output as a map of where to read. Read the templates whole.

## Replace, don't ask

Convert every hand-written piece an existing component covers, without asking first. Then name each visible change in your reply.

**Snap to the nearest existing variant rather than overriding one.** A button the mockup colored or sized by hand becomes the closest `UI::Button` / `UI::ButtonLink` `color:` and `size:`, with the override classes deleted. Don't write `html_class: "tw:bg-[#…]! tw:px-8!"` to keep the mockup's look. A badge gets the nearest `UI::Badge` `color:`, and a card the nearest `UI::Card` `shadow:`. Never add a `UI::*` argument to keep a mockup's exact look. The nearest variant is the answer.

`!` is for layout only (width, padding, grid placement), on a class that the component's own class outranks. `Pages::RecoveryStories::Index` puts `tw:p-7!` on `UI::Card`.

## Marketing pages: `SharedBlocks::Marketing`

A marketing page is a `for_*` landing page, or the donate, recovery stories, e-bike rules, marketplace "how it works" or register landing page, or one like them. It goes together from this kit, not from `ui/` alone. A design handoff draws these blocks by hand, so its mock is no sign they're missing:

| Hand-written | Use |
|---|---|
| The page root (`tw:-mt-(--nav-gap) tw:-mb-(--footer-gap) tw:bg-white …`) and its font `<link>` | `SharedBlocks::Marketing::Wrapper`, rendered from the controller (`render SharedBlocks::Marketing::Wrapper::Component.new(page: …)`) |
| A section's content width (`tw:mx-auto tw:max-w-6xl tw:px-…`) | `SharedBlocks::Marketing::Wrapper::Component::CONTAINER_CLASSES` |
| An `h2` with an eyebrow or intro paragraph | `SharedBlocks::Marketing::SectionHeading` (`eyebrow:`, `eyebrow_color:`, `intro:`) |
| An eyebrow on its own | `SharedBlocks::Marketing::SectionHeading::Component.eyebrow_classes(color)` |
| An icon in a colored circle beside a title and body | `SharedBlocks::Marketing::IconFeature` (`card: true` for the bordered tile) |
| Bikes registered, recoveries, value returned, partners | `SharedBlocks::Marketing::RegistryStats`. It reads `Counts` itself, so the controller passes nothing |
| Other figure/label blocks | `SharedBlocks::Marketing::NumberBlocks` |
| A colored band with a heading and a button | `SharedBlocks::Marketing::CallToActionBanner` |
| A gradient two-column band | `SharedBlocks::Marketing::InvertedBlock` |
| A strip of recovery stories | `SharedBlocks::Marketing::RecoveryStories` |
| Any donation or membership form | `Pages::Donate::Form` in a `UI::Card`, the way `Pages::RecoveryStories::Index` embeds it, with its own `referral_source:` |
| An FAQ | `UI::Accordion` |

`Pages::Register::Views::Landing` is the worked example. Its hand-rolled $5/$15/$50 donation form and a stats strip that took four counts from the controller both became the components above.

## Everywhere else: `UI::*` and `Atoms::*`

Read `app/components/ui/` and `app/components/atoms/`, plus the sibling `pages/` and `shared_blocks/` components that render the same thing. Convert:

- cards to `UI::Card`
- headings to `UI::Header`
- link rows to `UI::ButtonGroup`
- pills to `UI::Badge`
- a `link_to … method:` to `UI::ButtonLink`

A class map that repeats another component's moves to something both of them already render.

## Icons: use the file that's already there

Check **every icon the branch adds or newly references**. For each one, ask whether the repo already has it, and if so, use the existing file and delete the added one. Look in:

- all of `app/assets/images/` (not just `icons/`), including the `lucide-*` copies another redesign brought in
- `app/javascript/bikebook/templates/icons.js`
- text glyphs in templates

Check two ways:

```bash
# The same drawing under another name
d=$(grep -o 'd="[^"]*"' app/assets/images/icons/<new>.svg | head -1); grep -rlF -- "$d" app
# The same subject under another name
ls app/assets/images/icons | grep -iE '<subject>|<synonym>'
```

On the register landing page, `store.svg` was a second Lucide store icon beside main's `lucide-store.svg`. A trailing arrow is the text `<span aria-hidden="true">→</span>` (`frontend-conventions` has that rule), not an `arrow-right.svg`.

## Images: use the original, never a copy

Check **every PNG, JPG, WebP or GIF the branch adds, in any directory**, not just the icons. A design handoff's illustrations are already in the repo. The drawn originals are in `kelsey_redesign/`, and a served one is a byte-identical copy under its original name in `app/assets/images/kelsey/illustrations/`. A handoff's copy comes resized, re-encoded and renamed, so neither a hash nor the filename matches. Search on the subject words instead, across the whole repo:

```bash
git ls-files | grep -iE '<subject>|<synonym>' | grep -iE '\.(png|jpe?g|webp|gif|svg)$'
```

Then open both files and compare the drawings. For a match:

- **Already served** (under `app/assets/images/`): reference that file.
- **Only in `kelsey_redesign/`**: copy it unchanged into `app/assets/images/kelsey/illustrations/`, keeping its original name.

Either way, delete the branch's copy. Never shrink or convert it to WebP to save bytes; pages already serve the originals.

The register landing page had four copies in `register_landing/`, all resized WebPs. `bike-hero.webp` was `comic-assets_bike-hero.png` (already on four pages), and `bike-bell.webp` was `comic-assets_bike-bell.png`. `u-lock.webp` and `stolen-alert.webp` were `comic-assets_u-lock.png` and `comic-assets_presentation-stolenalert.png`, which were only in `kelsey_redesign/` until then. A check of `icons/` alone missed all four.

## Shadows

- **Remove small shadows**: `tw:shadow-sm`, `tw:shadow`, `UI::Card` `shadow: :small`, or a `shadow-[…]` with a blur of a few pixels. On a static card a small shadow reads as a hover state (`UI::Card` says so). #4665 dropped them site-wide.
- **Keep big shadows, but call each one out in your reply**: `tw:shadow-md` and up, `UI::Card` `shadow: :large` or `:black`, and any `drop-shadow-[…]` on an image. The user decides whether each one stays.

## Hover states

**Call out every hover state on something that isn't a `UI::Button` or `UI::ButtonLink`**: a `hover:` utility on a card, tile, row or label, and a `group-hover:` or `has-[:hover]` effect. Say what it's on and what it does. Don't remove it. A `twlink` link's own hover is the standard link style, so leave it out.

## The reply

Always report, and lead with the conversions whenever there are any. The user should never find a change to their page that the reply didn't mention.

1. Each conversion, with the visible change it makes.
2. Each big shadow kept.
3. Each hover state on a non-button.
4. Each hand-written piece kept, and what no component covers.
