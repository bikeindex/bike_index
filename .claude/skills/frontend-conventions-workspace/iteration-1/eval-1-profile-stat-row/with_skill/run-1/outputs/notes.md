# Eval 1 — with_skill

All file-creation tools were denied. Returning produced content inline.

## Skill applied

`/Users/seth/conductor/workspaces/bikeindex/almaty-v1/.claude/skills/frontend-conventions/SKILL.md` — Tailwind `tw:` prefix on every class, `helpers.number_display` for every number, ViewComponent over partial with kw-args + instance variables, `helpers.` prefix only for view helpers.

## Source files inspected (read-only)

- `app/views/users/show.html.haml`
- `app/controllers/users_controller.rb`
- `app/models/user.rb` (line 468: `User#bikes(user_hidden = true)`)
- `app/helpers/application_component_helper.rb` (`number_display`, `amount_display`)
- `app/components/ui/{badge,card}/component.rb` for component style

## Files produced

### `outputs/app/components/users/stat_row_component.rb`

```ruby
# frozen_string_literal: true

module Users
  class StatRowComponent < ApplicationComponent
    def initialize(user:)
      @user = user
    end

    private

    def bikes_count
      @bikes_count ||= @user.bikes(false).count
    end

    # Bike has no value column on schema today; sum value_cents if it
    # exists so this degrades to 0 until a value field is added.
    def total_value_cents
      @total_value_cents ||= @user.bikes(false).sum { |bike| bike.try(:value_cents).to_i }
    end

    def total_value_dollars
      total_value_cents / 100
    end
  end
end
```

### `outputs/app/components/users/stat_row_component.html.erb`

```erb
<div class="tw:flex tw:flex-wrap tw:gap-6 tw:items-center tw:py-4 tw:px-4 tw:mb-4 tw:border tw:border-gray-200 tw:rounded-sm tw:bg-white tw:dark:bg-gray-800 tw:dark:border-gray-700">
  <div class="tw:flex tw:flex-col">
    <span class="tw:text-xs tw:uppercase tw:tracking-wide tw:text-gray-500 tw:dark:text-gray-400"><%= t(".registered_bikes") %></span>
    <span class="tw:text-2xl tw:font-bold tw:text-gray-900 tw:dark:text-gray-100">
      <%= helpers.number_display(bikes_count) %>
    </span>
  </div>

  <div class="tw:flex tw:flex-col">
    <span class="tw:text-xs tw:uppercase tw:tracking-wide tw:text-gray-500 tw:dark:text-gray-400"><%= t(".total_value") %></span>
    <span class="tw:text-2xl tw:font-bold tw:text-gray-900 tw:dark:text-gray-100">
      <span title="USD">$</span><%= helpers.number_display(total_value_dollars) %>
    </span>
  </div>
</div>
```

### `outputs/app/views/users/show.html.haml` (only diff: render the component as the first child of `.container`)

```haml
.user-page
  .container
    = render(Users::StatRowComponent.new(user: @user))
    .row
      ...
```

## Conventions satisfied

- `helpers.number_display(bikes_count)` and `helpers.number_display(total_value_dollars)` — every number through the helper.
- All Tailwind tokens prefixed `tw:` (incl. dark-mode variants).
- ViewComponent with `initialize(user:)` keyword arg + `@user` instance variable, no `attr_accessor`.
- `helpers.` only on view helpers; no path helpers in template.
