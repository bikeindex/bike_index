---
name: manufacturers
description: >-
  Add or update a manufacturer in Bike Index production through the admin OAuth
  token (POST and PATCH /admin/manufacturers). Trigger when the user asks to
  add, create, register, rename or edit a manufacturer or brand in production,
  or whether Bike Index already has one.
---

# Adding or updating a manufacturer

Uses the `admin-data-api` skill's helper and token — its SKILL.md covers auth, refresh and 401/403. The token's user needs the `manufacturers` superuser ability (or a universal one).

## 1. Check it isn't there already

```
curl -s https://bikeindex.org/api/v3/manufacturers/<name>
```

A 404 means nothing matches. It looks up the way `Manufacturer.friendly_find` does — slug, then the name in parentheses — so try the brand's other spellings too, and a match is the manufacturer to use rather than one to add.

## 2. Confirm the attributes

Production write — only for a name the user has confirmed in this conversation. Settle with them:

- `name` — the brand as it brands itself, plus its other name in parentheses whenever it has one — a company name, a former name, a spelled-out abbreviation (`TQ (TQ-Systems)`). The parenthesized name becomes the `secondary_slug`, so a search for either finds it.
- `website`, `frame_maker` (makes frames, not just components), `motorized_only` (e-bikes/scooters only).

The rest of `Admin::ManufacturersController#permitted_parameters` is optional.

## 3. Create

```
.claude/skills/admin-data-api/scripts/admin_data.rb create-manufacturer name="Zoomo" website=https://zoomo.com frame_maker=true motorized_only=true
```

Returns the new manufacturer; a 422 prints the validation errors (`Manufacturer` validations — a taken name or slug, a color name, a quote). Link the user to `https://bikeindex.org/admin/manufacturers/<slug>`.

## Updating

```
.claude/skills/admin-data-api/scripts/admin_data.rb update-manufacturer <slug> name="TQ (TQ-Systems)"
```

Takes the same attributes as create, and only the ones passed change. Production write — confirm the new values with the user first. The slug comes from the name outside the parentheses, so adding a secondary name leaves the slug and admin URL unchanged.
