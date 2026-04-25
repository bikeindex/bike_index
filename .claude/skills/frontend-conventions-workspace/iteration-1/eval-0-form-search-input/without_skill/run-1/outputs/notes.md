# Eval 0 — without_skill (baseline)

Write was fully blocked in this sandbox. Delivering deliverables inline.

## Key finding from the codebase

There is no `bikes#index` action — `config/routes.rb` line 171 declares `resources :bikes, except: %i[index edit]`. The "bikes index page" is `search/registrations#index` (`/bikes` is not a route; the actual path is `search_registrations_path`). The existing search reads a `:serial` param via `BikeSearchable.searchable_interpreted_params`.

## Files produced

### `outputs/app/views/search/registrations/_serial_search.html.erb`

```erb
<div class="tw:mx-auto tw:mb-4 tw:max-w-7xl tw:px-4">
  <%= form_with(url: search_registrations_path, method: :get, local: true,
      class: "tw:flex tw:flex-col tw:gap-2 tw:sm:flex-row tw:sm:items-end") do %>
    <div class="tw:flex-grow">
      <%= label_tag :serial, t(".search_by_serial_number"), class: "twlabel" %>
      <%= text_field_tag :serial, params[:serial],
        placeholder: t(".serial_placeholder"),
        class: "twinput tw:w-full", autocomplete: "off" %>
    </div>
    <%= submit_tag t(".search"),
      class: "tw:rounded tw:bg-blue-600 tw:px-4 tw:py-2 tw:text-white tw:hover:bg-blue-700" %>
  <% end %>
</div>
```

### `outputs/app/views/search/registrations/index.html.erb` (modified — adds one render line at the top)

```erb
<%= render "serial_search" %>

<div class="tw:mx-auto tw:mb-6 tw:max-w-7xl tw:px-4">
  <h1 class="tw:mb-4 tw:text-3xl tw:text-slate-800">Search all registrations</h1>
  <%= render Search::Form::Component.new(target_search_path: search_registrations_path,
    target_frame: :search_registrations_results_frame,
    interpreted_params: @interpreted_params, result_view: @result_view) %>
</div>

<%= turbo_frame_tag :search_registrations_results_frame do %>
  <% if @render_results %><%= render partial: "results" %>
  <% else %><span id="loadedWithoutResults" class="tw:hidden"></span><% end %>
<% end %>

<div id="hiddenLoadingSpinner" class="tw:hidden">
  <%= render UI::LoadingSpinner::Component.new(text: t(".loading_results")) %>
</div>
```

## Decisions

- Submits GET to `search_registrations_path` reusing the `:serial` param (round-trips through `BikeSearchable`).
- Uses `twinput`/`twlabel` and `tw:`-prefixed Tailwind per the existing `Search::Form::Component` template.
- Kept it `local: true` so it's a simple page nav and doesn't fight the existing turbo-frame combobox flow.
- Relevant existing files: `app/views/search/registrations/index.html.erb`, `app/components/search/form/component.html.erb`, `app/controllers/search/registrations_controller.rb`.
