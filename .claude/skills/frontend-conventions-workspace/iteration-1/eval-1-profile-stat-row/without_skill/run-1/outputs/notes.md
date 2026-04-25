# Eval 1 — without_skill (baseline)

The harness blocked all writes/mkdir/touch. Delivering would-be file contents inline.

## Files investigated (read-only)

- `app/views/users/show.html.haml`
- `app/controllers/users_controller.rb`
- `app/models/user.rb` (User#bikes scope, line 468)
- `app/helpers/application_component_helper.rb` (number_display)
- `app/services/money_formatter.rb`
- `db/structure.sql` (no value column on bikes; `marketplace_listings.amount_cents` exists)

**Key finding:** `bikes` has no value/price column. Only per-bike monetary value is `marketplace_listings.amount_cents` (polymorphic on Bike).

## Would-be outputs

### `outputs/app/views/users/show.html.haml` — adds, between the description block and the `%h3= t(".bikes")` row

```haml
.row.tw:mt-4.tw:mb-4
  .col-md-12
    .tw:flex.tw:flex-wrap.tw:gap-6.tw:border-y.tw:border-gray-200.tw:py-4
      .tw:flex.tw:flex-col
        %span.tw:text-xs.tw:uppercase.tw:tracking-wide.tw:text-gray-500
          = t(".registered_bikes")
        %span.tw:text-2xl.tw:font-semibold
          = number_display(@bikes_count)
      .tw:flex.tw:flex-col
        %span.tw:text-xs.tw:uppercase.tw:tracking-wide.tw:text-gray-500
          = t(".total_value")
        %span.tw:text-2xl.tw:font-semibold
          = MoneyFormatter.money_format_without_cents(@bikes_total_value_cents)
```

### `outputs/app/controllers/users_controller.rb` — `#show` additions

```ruby
user_bikes = user.bikes(false)
@pagy, @bikes = pagy(:countish, user_bikes, limit: @per_page, page: permitted_page)
@bikes_count = user_bikes.count
@bikes_total_value_cents = MarketplaceListing
  .where(item_type: "Bike", item_id: user_bikes.select(:id), status: :for_sale)
  .sum(:amount_cents)
```

## Decisions

- Reused `User#bikes(false)` (matches visible list).
- Summed `marketplace_listings.amount_cents` for the value (no bike value column exists).
- Used `tw:` prefix to avoid clashing with legacy Bootstrap classes still on this page.
- `number_display` for count, `MoneyFormatter.money_format_without_cents` for currency (NOT through `number_display`).
- New i18n keys `users.show.registered_bikes` / `users.show.total_value` (locale YAML edit trivial, omitted).
