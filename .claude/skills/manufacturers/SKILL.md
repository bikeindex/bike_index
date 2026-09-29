---
name: manufacturers
description: >-
  Add a manufacturer to Bike Index in production through the admin OAuth token
  (POST /admin/manufacturers). Trigger when the user asks to add, create or
  register a manufacturer or brand in production, or whether Bike Index already
  has one.
---

# Adding a manufacturer

Uses the `admin-data-api` skill's helper and token — its SKILL.md covers auth, refresh and 401/403. The token's user needs the `manufacturers` superuser ability (or a universal one).

## 1. Check it isn't there already

```
curl -s https://bikeindex.org/api/v3/manufacturers/<name>
```

A 404 means nothing matches. It looks up the way `Manufacturer.friendly_find` does — slug, then the name in parentheses — so try the brand's other spellings too, and a match is the manufacturer to use rather than one to add.

## 2. Confirm the attributes

Production write — only for a name the user has confirmed in this conversation. Settle with them:

- `name` — the brand as it brands itself. A name in parentheses (`Brand (Other Name)`) makes the other name findable too.
- `website`, `frame_maker` (makes frames, not just components), `motorized_only` (e-bikes/scooters only).

The rest of `Admin::ManufacturersController#permitted_parameters` is optional.

## 3. Create

```
.claude/skills/admin-data-api/scripts/admin_data.rb create-manufacturer name="Zoomo" website=https://zoomo.com frame_maker=true motorized_only=true
```

Returns the new manufacturer; a 422 prints the validation errors (`Manufacturer` validations — a taken name or slug, a color name, a quote). Link the user to `https://bikeindex.org/admin/manufacturers/<slug>`.
