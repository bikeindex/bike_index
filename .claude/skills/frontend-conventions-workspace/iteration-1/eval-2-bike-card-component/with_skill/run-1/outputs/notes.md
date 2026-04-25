# Eval 2 — with_skill

All Write and Bash mkdir attempts were denied. Delivering artifacts inline.

## Context used (read-only)

`app/components/application_component.rb`, `app/components/member_badge/component.{rb,html.erb}`, `app/components/search_results/bike_box/component.{rb,html.erb}`, `app/views/bikes/_bike.html.erb`, `app/views/search/registrations/_results.html.erb`, `app/helpers/application_component_helper.rb`, `app/models/bike.rb`. There is no real `bikes/index.html.erb` in the codebase (only `show`/`new`); the closest list is `search/registrations/_results.html.erb`, which renders `partial: '/bikes/bike', collection: @bikes`. I treated that as the "bikes index page" target.

## Conventions applied (per `frontend-conventions/SKILL.md`)

Keyword-arg `initialize`, instance variables (no `attr_accessor`), subclasses `ApplicationComponent`, template uses `helpers.` for view helpers (not paths), `tw:` prefix on every Tailwind class, `twlink`/`twlabel` for link + labels, `number_display(...)` for `year` and `value`.

## Files produced

### `outputs/app/components/bike_card_component.rb`

```ruby
# frozen_string_literal: true

class BikeCardComponent < ApplicationComponent
  def initialize(bike:)
    @bike = bike
  end

  def render?
    @bike.present?
  end

  private

  def title
    [@bike.year, @bike.mnfg_name, @bike.frame_model].compact_blank.join(" ")
  end
end
```

### `outputs/app/components/bike_card_component.html.erb`

```erb
<li class="tw:rounded tw:border tw:border-gray-200 tw:dark:border-gray-700 tw:p-4 tw:flex tw:flex-col tw:gap-2">
  <%= helpers.link_to title, @bike.html_url, class: "twlink tw:font-semibold", data: {turbo: false} %>

  <dl class="tw:grid tw:grid-cols-[auto_1fr] tw:gap-x-3 tw:gap-y-1 tw:text-sm">
    <dt class="twlabel">Manufacturer</dt>
    <dd><%= @bike.mnfg_name %></dd>

    <dt class="twlabel">Year</dt>
    <dd>
      <% if @bike.year.present? %><%= helpers.number_display(@bike.year) %><% else %>&mdash;<% end %>
    </dd>

    <dt class="twlabel">Frame model</dt>
    <dd><%= @bike.frame_model.presence || "—" %></dd>

    <dt class="twlabel">Value</dt>
    <dd>
      <% if @bike.value.present? %><%= helpers.number_display(@bike.value) %><% else %>&mdash;<% end %>
    </dd>
  </dl>
</li>
```

### `outputs/app/views/bikes/index.html.erb`

```erb
<div class="container tw:mb-8">
  <% if @bikes.present? %>
    <ul class="tw:grid tw:grid-cols-1 tw:md:grid-cols-2 tw:lg:grid-cols-3 tw:gap-4 tw:list-none tw:p-0">
      <% @bikes.each do |bike| %>
        <%= render(BikeCardComponent.new(bike:)) %>
      <% end %>
    </ul>
  <% else %>
    <h3 class="tw:text-center tw:mt-8">No bikes found</h3>
  <% end %>
</div>

<% if @bikes.present? && @pagy.present? %>
  <%= render(UI::Pagination::Component.new(pagy: @pagy, page_params: params,
    size: :lg, data: {turbo_action: "advance"})) %>
<% end %>
```

## Notes / decisions

Used flat `BikeCardComponent` layout (matches the task name and `rails generate component`); project also uses namespaced layout (`SearchResults::BikeBox::Component`) — both are valid here. `bike.mnfg_name` is the canonical display name on `Bike`. `bike.value` isn't a column on `Bike` but the task specified it; rendered through `number_display` with a presence guard. No Stimulus controller (purely presentational). Replaces `render partial: '/bikes/bike', collection: @bikes` (used by `search/registrations/_results.html.erb`) with the new component.
