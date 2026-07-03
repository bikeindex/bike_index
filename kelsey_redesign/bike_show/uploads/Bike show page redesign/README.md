# Handoff: Bike Index — Bike Show Page Redesign

## Overview
This is a redesign of the Bike Index **"bike show"** page — the detail page for an individual
registered bike. The redesign reframes the page from a plain data table into an **action hub**
and splits it into clearly-scoped views by audience and permission:

- **Admin / staff views** — used by organizations (e.g. universities) to manage bikes: message
  the owner, impound, send parking notifications, view notification history, audit e-vehicles,
  and keep internal notes.
- **Consumer views** — the public-facing "home for your bike on the internet": a photo-forward
  showcase, with a separate **owner** version (adds Marketplace selling and management) and a
  **public** version (anonymous — contact owner, share, report sighting).

All views exist at **desktop and mobile** breakpoints with identical data and permission rules.

The original brief is included in this bundle: `BikeIndex_Admin_Designer_Brief.pdf`.

## About the Design Files
The files in this bundle are **design references created in HTML** — prototypes that show the
intended look, layout, and behavior. They are **not production code to copy directly**.

These particular `.dc.html` files are authored in a proprietary "Design Component" runtime
(`support.js`) using a small template + logic-class format. **Do not try to reuse that runtime.**
Treat the files as a visual + behavioral spec and **recreate the designs in your target
codebase's existing environment** (React, Vue, Rails/ERB, SwiftUI, etc.) using its established
component library, styling system, and patterns. If no front-end environment exists yet, pick
the framework most appropriate for the project and implement there.

To view the prototypes: open `Bike Show Redesign.dc.html` in a browser. It is a canvas that lays
out all nine frames (5 desktop + 4 mobile) with labels. The individual `Bike*.dc.html` files are
the single views.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, and interaction intent are all specified.
Recreate the UI to match — exact hex values, type scale, and radii are listed in **Design Tokens**
below. Photographic imagery is represented by placeholder "drop zones" (the `image-slot.js`
component); in production these become real bike photos from the Bike Index media store.

---

## Permission & audience model (read this first)

Three viewer contexts drive everything. Get this right before building screens.

**Admin / staff** (one combined role — admins and employees see the *same* bike view; admins
additionally have org-management powers like sending emails, but the bike page itself is identical):
- Full owner contact (name, email, phone), registration #, date.
- All actions: Message owner, Impound (single confirmation), Parking notice, View notifications.
- E-vehicle audit + owner attestation.
- Internal notes thread + composer.
- "Other registrations by this user" list (labeled law-enforcement access).

**Limited (RA)** — a restricted staff role:
- Owner contact is **hidden**.
- No "Message owner" or "Parking notice"; Impound becomes **"Request impound"** (sent for approval, amber styling).
- Can still read/add notes.
- "Other registrations" list hidden.

**Bike not registered with the org** (admin/staff viewing an out-of-org bike):
- Same layout as staff, but owner/contact panel is **hidden** (replaced with an explanatory dashed card).
- Notes still allowed. "Other registrations" hidden.

**Consumer — owner**: photo showcase + Sell on Marketplace, Share my page, Mark stolen, edit photos.

**Consumer — public** (anyone who is not the owner): same showcase, but anonymous actions only —
Contact owner via Bike Index (owner identity stays private), Share, Report sighting. No owner/management actions.

The HTML implements these as props:
- `BikeAdminView` / `BikeAdminMobile`: `variant` = `"staff" | "limited"`, `orgRegistered` = boolean, `notifCount` = number.
- `BikeConsumerView` / `BikeConsumerMobile`: `isOwner` = boolean.

---

## Screens / Views

### 1. Admin / Staff — desktop (`BikeAdminView.dc.html`, variant=staff, orgRegistered=true)
**Purpose:** Org staff manage an individual bike registered to their organization.

**Layout:** A rounded container (radius 16px, border `#e5e5e5`, shadow `0 8px 30px rgba(17,17,26,.10)`)
on a `#fafafa` page. Top to bottom:
1. **Context bar** (white, bottom border `#e5e5e5`, padding 12px 26px): left = purple "B" chip
   (26px, radius 7px, `#715eb2`) + monospace breadcrumb `Bikes / #2918844`; right = org chip,
   role label, and a 30px circular avatar `#3397dc` with initials "KD".
2. **Header** (white, padding 24px 30px 20px): `<h1>` 27px/800 — "2022 Trek **X-Caliber**"
   (model in 500 weight `#6b6b73`) + monospace nickname "Cosmo's Trek". Below: status pills
   (Registered / Claimed / Not stolen). Right-aligned: "Registration" label + mono `#2918844` + date.
3. **Quick action bar** (white, padding 0 30px 20px): a flex row of equal-weight action cards
   (flex:1, padding 14px 16px, border `#e5e5e5`, radius 12px; hover `background:#f7f5fc;
   border-color:#715eb2`). Each card = a 38px rounded icon tile (radius 9px) + a title (14.5px/700)
   and a sub-label (12px `#9a9aa2`). Cards: **Message owner** (Email & SMS), **Impound**
   (Single confirmation), **Parking notice** (Abandoned · incorrect), **View notifications**
   (Parking activity) — the last has an absolutely-positioned count badge (top:9px right:12px,
   `#3397dc` pill, white 11.5px/800).
4. **Workspace grid** (padding 22px 30px 26px), `grid-template-columns:1.55fr 1fr; gap:20px`:
   - **Main column** (cards, each: white, border `#e5e5e5`, radius 14px, padding 20px 22px,
     shadow `0 1px 2px rgba(17,17,26,.04)`; section eyebrow = 12px/700, uppercase,
     letter-spacing .05em, `#9a9aa2`):
     - **Photo archive** — "From past interactions" — 4-col grid of 96px tiles, each with a
       caption (Registration · May 7, Parking notif · May 3, Impound check · Apr 2, Registration · Apr 2).
     - **Bike details** — 3-col grid. **Field order: Serial → Bike Index Registration (#2918844)
       → Credibility (100, "· no dup. serials") → Manufacturer → Model → Year → Primary colors
       (red swatch) → Frame material → Frame size.** (Note: "Primary activity" was intentionally
       removed.)
     - **Internal notes** — a thread of entries: 30px circular avatar + name + role + timestamp
       + note body, separated by `#f3f3f3` rules. Two seed entries (K. Dewey · Admin · May 12;
       R. Hooch · RA · May 9). The composer lives in the aside (see below) so old notes are never overwritten.
     - **Other registrations by this user** — "law-enforcement access" — rows of date + colored
       bike name. (Hidden when contact is hidden.)
   - **Aside column:**
     - **Owner & access** — name, email (`#3397dc`), phone (mono, click-to-call), divider,
       Registration # (mono), Registered date, and a purple info card (`#f0edfa`) "Hogwarts can
       edit this bike" with Edit access / Link sticker links. When contact is hidden, this whole
       block is replaced by a dashed `#fafafa` card with a title + explanation.
     - **E-vehicle compliance** — two rows: **Audit** (Not audited → "Start audit" button) and
       **Owner attestation** (Not attested → "Request" button).
     - **Parking notifications** — eyebrow + count badge; two stat tiles (Current = notifCount,
       Resolved = 3); "Open notifications page →" link. This is the **swappable sub-widget** that
       pairs with the View notifications quick action.
     - **Add a note** — textarea (placeholder reminds notes are kept in thread) + "Posts as
       K. Dewey" + purple **Post note** button (`#715eb2`).
5. **Toast** — absolutely positioned bottom-center, `#333` pill, fires on any action (mock feedback).

### 2. Limited / RA — desktop (`BikeAdminView`, variant=limited, orgRegistered=true)
Same layout. Differences: role label "Limited · RA"; **no Message / Parking-notice actions**;
Impound → **Request impound** (amber icon tile `#fff8e1` / `#caa11a`, "Sent for approval");
**Owner & access** shows the restricted dashed card ("Restricted for your role…"); **Other
registrations** hidden.

### 3. Admin — bike NOT registered with org (`BikeAdminView`, variant=staff, orgRegistered=false)
Same as staff, but org chip reads "Not in your org" (amber `#fff5e0` / `#9a7a1c`); **Owner &
access** shows dashed card "Not registered with Hogwarts — Owner contact isn't available for bikes
outside your organization. You can still add internal notes."; Other registrations hidden.

### 4. Consumer — owner (`BikeConsumerView.dc.html`, isOwner=true)
**Purpose:** The bike owner's public page / "home for your bike."
**Layout:** Rounded container. Public nav bar (B chip + "Bike Index" wordmark; right = mono URL
`bikeindex.org/bikes/2918844` + audience pill "Your bike" green `#1f8a5b`). **Hero** = 2-col grid
(1.4fr / 1fr):
- Left: gallery — a 360px hero image-slot + a 4-col thumbnail row (3 photos + an "Add" dashed tile for owner).
- Right: summary on a soft `#f7f5fc→#fafafa` gradient — `<h1>` 30px/800 "Cosmo's Trek",
  subtitle "2022 Trek X-Caliber · Red", **badges** (now only "Registered & protected" `#e7f3fb`
  and "Not stolen" `#e8f5ee` — Hot-or-Not and Cool Bike Check were removed), then primary actions
  pushed to the bottom: **Sell on Marketplace** (`#715eb2`, 800), and a row of **Share my page** +
  **Mark stolen** (`#c0392b` text, `#f3c9c9` border).
Below hero: a 5-cell **specs strip** (Frame, Activity, Color, Year, Status) with 1px `#eee`
dividers. Bottom: a single full-width **About this bike** card (the Cool Bike Check / sticker promo
band was removed).

### 5. Consumer — public (`BikeConsumerView`, isOwner=false)
Same showcase, audience pill "Public view" (blue `#3397dc`). Thumbnail "+5 more" tile instead of
Add. Primary action = **Contact owner via Bike Index** (owner identity stays private), with
**Share** + **Report sighting**. No Marketplace / Mark stolen / edit.

### 6–9. Mobile views (`BikeAdminMobile.dc.html`, `BikeConsumerMobile.dc.html`)
390px-wide phone layouts shown in device frames on the canvas. Same data and permission logic as
desktop, re-flowed into a single column.
- **Admin mobile** is field-action first: status bar, app bar (back chevron + reg # + org chip),
  compact hero (title, pills, thumbnail strip), then a **2×2 quick-action grid** (Message,
  Impound, Notice, Notifications-with-count) with min 60px hit targets, then Owner & access (phone
  is a real `tel:` link), notes thread + composer, Bike details (Serial → Bike Index Reg # →
  Credibility → Frame → Color → Year), and Other registrations.
- **Consumer mobile** is photo-forward: full-bleed 300px hero with title overlaid on a dark
  gradient, thumbnail strip, badges, primary action(s) by role, specs strip, and an About card.

---

## Interactions & Behavior
- **Every action button** currently fires a transient toast (bottom-center, ~2s) as mock
  feedback. In production each maps to a real flow:
  - *Message owner* → compose email + SMS to owner.
  - *Impound* (staff) → **single-confirmation** impound; the brief calls for confirming/选择 an
    existing or new location via a map pin. *(Not yet mocked — implement as a confirm step.)*
  - *Request impound* (limited) → submit for admin approval.
  - *Parking notice* → create a parking notification (abandoned / incorrectly parked).
  - *View notifications* → navigate to the bike's parking-notifications page; the on-page
    Parking-notifications widget is the in-place counterpart.
  - *Audit / Attestation* → start e-vehicle audit / request owner attestation.
  - *Post note* → append to the notes thread with current user + timestamp (never overwrite).
  - *Sell on Marketplace / Mark stolen / Share / Contact owner / Report sighting* → respective flows.
- **Click-to-call**: owner phone is a `tel:` link on mobile.
- **Hover** (desktop action cards): `background:#f7f5fc; border-color:#715eb2`.
- **Responsive**: the desktop multi-column workspace collapses to a single mobile column; action
  cards become a 2×2 grid. Treat 390px as the mobile design width and ~1180px as the desktop view width.

## State Management
Minimal — these are presentational views. State needed in production:
- **Viewer context**: role (`staff` | `limited`), whether the bike is org-registered, and
  ownership (`isOwner`) for consumer views. These gate which actions/panels render.
- **notifCount**: number of current parking notifications (drives the badge + stat tile).
- **Notes**: an append-only list of `{author, role, timestamp, body}`.
- **Toast**: transient message string (replace with your app's real toast/flash system).
- **Photos**: gallery + archive image lists fetched from the media store.

## Design Tokens

**Colors**
- Primary purple: `#715eb2` (darker `#5d4b9c`); purple tint bg `#f0edfa`; purple text `#5d4b9c`.
- Blue: `#3397dc`; dark blue `#016ec2`; blue tint bg `#e7f3fb`.
- Accent yellow: `#ffd660` (text-on-yellow `#5a4708`).
- Success green: `#1f8a5b`; green tint bg `#e8f5ee`.
- Amber (limited/warn): icon `#caa11a`, bg `#fff8e1`, chip `#fff5e0` / text `#9a7a1c`.
- Danger: `#c0392b`, border `#f3c9c9`.
- Red color-swatch: `#e23b3b`.
- Neutrals: page `#fafafa`; card white `#ffffff`; borders `#e5e5e5` and hairlines `#f0f0f0`/`#f3f3f3`;
  text `#333`; secondary `#5b5b63` / `#6b6b73`; muted `#9a9aa2`; faint `#b3b3b9`; device bezel `#1a1a1f`.

**Typography**
- UI font: **Hanken Grotesk** (400/500/600/700/800).
- Monospace (IDs, serial, phone): **JetBrains Mono** (400/500/600).
- Scale: h1 desktop 27–30px/800; mobile h1 23–25px/800; section eyebrow 11–12px/700 uppercase,
  letter-spacing .05–.06em; body 13–15px; labels 11–12px; sub-labels 12px.

**Radius**: cards 14px; container 16px; action cards 11–13px; icon tiles 8–9px; pills 999px;
phone bezel 46px (inner screen 38px).

**Shadow**: card `0 1px 2px rgba(17,17,26,.04)`; container `0 8px 30px rgba(17,17,26,.10)`;
toast `0 10px 30px rgba(0,0,0,.25)`; phone `0 24px 60px rgba(0,0,0,.28)`.

**Spacing**: card padding 16–22px; workspace gap 18–20px; mobile gutters 18px; action min hit
target 60px (mobile).

## Assets
- **Icons** are inline SVG (stroke-based, ~1.7–2.2 stroke width) — envelope, lock/impound,
  map-pin, bell, camera, shield, check, clock. Recreate with your icon library (Lucide/Feather
  match the style closely).
- **Photos**: represented by `image-slot.js` placeholder drop-zones. In production, wire to real
  Bike Index bike photos (hero + gallery for consumer; archive of interaction photos for admin).
- **Fonts**: Hanken Grotesk + JetBrains Mono via Google Fonts.
- No raster brand assets are required; the "B" chip is a simple typographic mark.

## Files
- `Bike Show Redesign.dc.html` — **canvas** laying out all 9 frames with labels (start here).
- `BikeAdminView.dc.html` — admin/staff desktop view (props: `variant`, `orgRegistered`, `notifCount`).
- `BikeAdminMobile.dc.html` — admin/staff mobile view (same props).
- `BikeConsumerView.dc.html` — consumer desktop view (prop: `isOwner`).
- `BikeConsumerMobile.dc.html` — consumer mobile view (prop: `isOwner`).
- `image-slot.js`, `support.js` — runtime/helpers for the prototype only; **do not port**.
- `BikeIndex_Admin_Designer_Brief.pdf` — the original product brief.
- `screenshots/` — rendered reference images of each state (see below).

## Screenshots
Rendered references of the primary states (in `screenshots/`):
- `01-admin-staff-desktop.png` — Admin / staff, org-registered bike (full access).
- `02-admin-limited-desktop.png` — Limited (RA) role: contact hidden, "Request impound", no message/parking actions.
- `03-admin-nonorg-desktop.png` — Staff viewing a bike not registered with the org: owner panel replaced by an explanatory card.
- `04-consumer-owner-desktop.png` — Consumer, owner: showcase + Sell on Marketplace / Share / Mark stolen.
- `05-consumer-public-desktop.png` — Consumer, public (not the owner): anonymous Contact owner / Share / Report sighting.
- `06-admin-mobile.png` — Admin / staff mobile (field-action first, 2×2 quick-action grid).
- `07-consumer-mobile.png` — Consumer mobile, photo-forward showcase.

Mobile limited/non-org and consumer-public mobile states follow the same prop rules as their desktop counterparts (documented above) and aren't separately captured.

> Implementation note: the `.dc.html` files use a template syntax (`{{ }}` holes, `<sc-if>`,
> `<dc-import>`) specific to the prototyping runtime. Read them for structure, copy, and styling —
> then rebuild as ordinary components in your stack. The exact colors, type, spacing, and copy
> above are the source of truth.
