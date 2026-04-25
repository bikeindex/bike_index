# Eval 0 — with_skill

**Permission denied: cannot write to outputs directory.** Both `Write` and `Bash mkdir` were rejected for the outputs directory. Delivering artifacts inline.

## Files produced

### `outputs/app/views/bikes/index.html.erb`

```erb
<div class="tw:mx-auto tw:mb-6 tw:max-w-7xl tw:px-4">
  <h1 class="tw:mb-4 tw:text-3xl tw:text-slate-800">
    Bikes
  </h1>

  <%= render Bikes::SerialSearchForm::Component.new %>
</div>
```

### `outputs/app/components/bikes/serial_search_form/component.rb`

```ruby
# frozen_string_literal: true

module Bikes
  module SerialSearchForm
    class Component < ApplicationComponent
      def initialize(serial: nil)
        @serial = serial
      end
    end
  end
end
```

### `outputs/app/components/bikes/serial_search_form/component.html.erb`

```erb
<%= form_with(url: search_registrations_path, method: :get, local: true,
    class: "tw:mb-6 tw:flex tw:flex-nowrap tw:gap-3 tw:items-end") do |f| %>
  <div class="tw:flex-grow">
    <%= f.label :serial, translation(".search_by_serial_number"), class: "twlabel" %>
    <%= f.text_field :serial, value: @serial,
      placeholder: translation(".serial_placeholder"),
      class: "twinput tw:w-full" %>
  </div>

  <%= f.submit translation(".submit"), class: "twbtn-blue" %>
<% end %>
```

### `outputs/app/components/bikes/serial_search_form/component.en.yml`

```yaml
en:
  components:
    bikes:
      serial_search_form:
        component:
          search_by_serial_number: "Search by serial number"
          serial_placeholder: "e.g. WSBC601234567"
          submit: "Search"
```

## Notes / decisions

- Submits GET to `search_registrations_path` (the existing search endpoint used by `app/views/search/registrations/index.html.erb`); `:serial` is in `Bike.permitted_search_params`.
- ViewComponent over partial; keyword-arg init; `@serial` instance variable (no `attr_accessor`); path helper unprefixed.
- Tailwind classes use `tw:` prefix; `twlabel`, `twinput`, `twbtn-blue` per skill (matches `Search::Form::Component`).
- No numbers rendered, so `number_display` not needed.
- Plain `local: true` form rather than turbo-frame, matching the "simple form" ask.
