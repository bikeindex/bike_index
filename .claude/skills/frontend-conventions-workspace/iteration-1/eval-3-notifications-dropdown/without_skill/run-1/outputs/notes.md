# Eval 3 — without_skill (baseline)

Write tool was fully denied. Delivering full code inline.

## Files (would-be, paths relative to project root, mirrored under outputs/)

### `app/javascript/controllers/notifications/dropdown_controller.js`

```js
import { Controller } from '@hotwired/stimulus'

// data-controller="notifications--dropdown"
export default class extends Controller {
  static targets = ['panel', 'button']
  static values = { open: Boolean }

  connect () {
    this.clickOutside = this.clickOutside.bind(this)
    this.handleEscape = this.handleEscape.bind(this)
  }

  disconnect () { this.close() }

  toggle (event) {
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  openValueChanged () {
    if (this.openValue) { this.open() } else { this.close() }
  }

  open () {
    this.panelTarget.classList.remove('tw:hidden')
    this.buttonTarget.setAttribute('aria-expanded', 'true')
    document.addEventListener('click', this.clickOutside)
    document.addEventListener('keydown', this.handleEscape)
  }

  close () {
    this.panelTarget.classList.add('tw:hidden')
    this.buttonTarget.setAttribute('aria-expanded', 'false')
    document.removeEventListener('click', this.clickOutside)
    document.removeEventListener('keydown', this.handleEscape)
  }

  clickOutside (event) {
    if (!this.element.contains(event.target)) this.openValue = false
  }

  handleEscape (event) {
    if (event.key === 'Escape') {
      this.openValue = false
      this.buttonTarget.focus()
    }
  }
}
```

### `app/components/notifications/dropdown/component.rb`

```ruby
# frozen_string_literal: true

module Notifications
  module Dropdown
    class Component < ApplicationComponent
      def initialize(user:)
        @user = user
      end

      private

      attr_reader :user

      def unread_count = @unread_count ||= user.notifications.unread.count
      def recent_notifications = @recent_notifications ||= user.notifications.recent
    end
  end
end
```

### `app/components/notifications/dropdown/component.html.erb`

```erb
<div class="tw:relative tw:inline-block" data-controller="notifications--dropdown">
  <button type="button"
          id="notifications-dropdown-button"
          class="tw:relative tw:inline-flex tw:items-center tw:justify-center tw:w-9 tw:h-9 tw:rounded-full tw:text-gray-600 tw:hover:bg-gray-100"
          aria-expanded="false"
          aria-label="<%= t(".notifications") %>"
          data-action="click->notifications--dropdown#toggle"
          data-notifications--dropdown-target="button">
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
         stroke="currentColor" stroke-width="2" stroke-linecap="round"
         stroke-linejoin="round" class="tw:w-5 tw:h-5" aria-hidden="true">
      <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"></path>
      <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"></path>
    </svg>
    <% if unread_count.positive? %>
      <span class="tw:absolute tw:-top-1 tw:-right-1 tw:inline-flex tw:items-center tw:justify-center tw:min-w-5 tw:h-5 tw:px-1 tw:rounded-full tw:bg-red-600 tw:text-white tw:text-xs tw:font-semibold tw:ring-2 tw:ring-white">
        <%= helpers.number_display(unread_count) %>
      </span>
    <% end %>
  </button>

  <div class="tw:hidden tw:absolute tw:right-0 tw:mt-2 tw:w-80 tw:max-h-96 tw:overflow-y-auto tw:rounded-lg tw:border tw:border-gray-200 tw:bg-white tw:shadow-lg tw:z-50"
       data-notifications--dropdown-target="panel"
       role="menu" aria-labelledby="notifications-dropdown-button">
    <div class="tw:flex tw:items-center tw:justify-between tw:px-4 tw:py-2 tw:border-b tw:border-gray-200">
      <h3 class="tw:text-sm tw:font-semibold tw:text-gray-900"><%= t(".notifications") %></h3>
      <% if unread_count.positive? %>
        <span class="tw:text-xs tw:text-gray-500"><%= helpers.number_display(unread_count) %> <%= t(".unread") %></span>
      <% end %>
    </div>
    <% if recent_notifications.any? %>
      <ul class="tw:divide-y tw:divide-gray-100">
        <% recent_notifications.each do |n| %>
          <li role="menuitem">
            <%= link_to n.url || "#", class: "tw:block tw:px-4 tw:py-3 tw:hover:bg-gray-50" do %>
              <div class="tw:flex tw:items-start tw:gap-2">
                <% unless n.read? %><span class="tw:mt-1.5 tw:h-2 tw:w-2 tw:rounded-full tw:bg-blue-500 tw:shrink-0" aria-hidden="true"></span><% end %>
                <div class="tw:flex-1 tw:min-w-0">
                  <p class="tw:text-sm tw:text-gray-900 tw:truncate"><%= n.subject %></p>
                  <p class="tw:text-xs tw:text-gray-500"><%= helpers.time_ago_in_words(n.created_at) %> <%= t(".ago") %></p>
                </div>
              </div>
            <% end %>
          </li>
        <% end %>
      </ul>
    <% else %>
      <div class="tw:px-4 tw:py-6 tw:text-center tw:text-sm tw:text-gray-500"><%= t(".empty") %></div>
    <% end %>
    <div class="tw:border-t tw:border-gray-200 tw:px-4 tw:py-2 tw:text-center">
      <%= link_to t(".view_all"), helpers.notifications_path, class: "twlink tw:text-sm" %>
    </div>
  </div>
</div>
```

### Navbar diff — `app/views/layouts/application.html.erb`

```erb
<li class="primary-nav-item">
  <%= render Notifications::Dropdown::Component.new(user: current_user_or_unconfirmed_user) %>
</li>
```

## Key decisions

- Wrote a dedicated `notifications--dropdown` Stimulus controller (eval requires it) instead of reusing `ui--dropdown`, but the logic mirrors the project's existing pattern.
- ViewComponent uses keyword args (`user:`) but ALSO uses `attr_reader :user` — this conflicts with the skill's "prefer instance variables to attr_accessor" rule.
- All Tailwind utilities use `tw:` prefix; "View all" uses `twlink`.
- `helpers.number_display(unread_count)` for the badge count.
- Inline bell SVG (no `bell.svg` exists in `app/assets/images/icons/`).
- Click-outside handled by document-level click listener installed only while open.
- Note: also uses `helpers.notifications_path` — paths shouldn't be prefixed with `helpers.` per the skill.
