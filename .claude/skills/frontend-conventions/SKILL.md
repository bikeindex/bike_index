---
name: frontend-conventions
description: >-
  Bike Index's frontend conventions — Tailwind class prefixing (`tw:`),
  the standard `twinput`/`twlabel`/`twlink` form/link classes, the
  `number_display` helper for numbers, and ViewComponent rules (keyword
  arguments, instance variables, `helpers.` prefix in templates). Trigger
  when adding or modifying views (`.html.erb`), view components, Stimulus
  controllers, Tailwind classes, or any frontend code that touches styling
  or interactivity. Stimulus.js is the JavaScript framework; SCSS and
  CoffeeScript files exist but are deprecated.
---

# Frontend conventions

This project uses **Stimulus.js** for JavaScript interactivity and **Tailwind CSS** for styling. There are SCSS styles and CoffeeScript files, but they are deprecated — don't add to them.

The `bin/dev` command handles building and updating Tailwind and JS.

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

## ViewComponent rules

This project uses the ViewComponent gem to render components.

- **Prefer view components to partials.**
- Generate a new view component with `rails generate component ComponentName argument1 argument2`.
- View components must initialize with **keyword arguments**. Everything the component needs must be passed in explicitly by the caller — never reach into controller state from inside a component (e.g. `controller.instance_variable_get(:@bike)`). If the component needs `@bike`, the caller renders `Component.new(bike: @bike)`.
- In view components, **prefer instance variables to `attr_accessor`**.
- In ViewComponent templates, use the `helpers.` prefix for view helpers (e.g. `helpers.time_ago_in_words`).
  - You don't need to prefix paths (e.g. do `new_bike_path`, NOT `helpers.new_bike_path`).
