# Eval 3 — with_skill

All write/mkdir operations were denied. Delivering full code inline.

## Files

### `outputs/app/components/notifications_dropdown/component.rb`

```ruby
# frozen_string_literal: true

module NotificationsDropdown
  class Component < ApplicationComponent
    def initialize(user:, limit: 8)
      @user = user
      @limit = limit
    end

    private

    def render?
      @user.present?
    end

    def notifications
      @notifications ||= @user.notifications.recent.limit(@limit)
    end

    def unread_count
      @unread_count ||= @user.notifications.unread.count
    end

    def has_unread?
      unread_count.positive?
    end
  end
end
```

### `outputs/app/components/notifications_dropdown/component.html.erb`

```erb
<%= render(UI::Dropdown::Component.new(
      name: "Notifications",
      button_class: "tw:relative tw:inline-flex tw:items-center tw:justify-center tw:rounded-full tw:p-2 tw:text-gray-700 tw:hover:bg-gray-100 tw:dark:text-gray-200 tw:dark:hover:bg-gray-700"
    )) do |dropdown| %>
  <% dropdown.with_button do %>
    <span class="tw:sr-only">Notifications</span>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" class="tw:h-6 tw:w-6">
      <path stroke-linecap="round" stroke-linejoin="round" d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0" />
    </svg>
    <% if has_unread? %>
      <span class="tw:absolute tw:-top-0.5 tw:-right-0.5 tw:inline-flex tw:items-center tw:justify-center tw:min-w-5 tw:h-5 tw:px-1 tw:rounded-full tw:bg-red-500 tw:text-white tw:text-xs tw:font-bold">
        <%= number_display(unread_count) %>
      </span>
    <% end %>
  <% end %>

  <% if notifications.any? %>
    <% notifications.each do |notification| %>
      <% dropdown.with_entry_item do %>
        <%= link_to notification_path(notification), class: "tw:flex tw:flex-col tw:gap-1 tw:px-4 tw:py-3 tw:hover:bg-gray-50 tw:dark:hover:bg-gray-700 #{"tw:font-semibold" unless notification.read?}" do %>
          <span class="tw:text-sm tw:text-gray-900 tw:dark:text-gray-100"><%= notification.title %></span>
          <span class="tw:text-xs tw:text-gray-500 tw:dark:text-gray-400">
            <%= helpers.time_ago_in_words(notification.created_at) %> ago
          </span>
        <% end %>
      <% end %>
    <% end %>
    <% dropdown.with_entry_divider %>
    <% dropdown.with_entry_item do %>
      <%= link_to "View all notifications", notifications_path, class: "twlink tw:block tw:px-4 tw:py-2 tw:text-sm tw:text-center" %>
    <% end %>
  <% else %>
    <% dropdown.with_entry_item do %>
      <span class="tw:block tw:px-4 tw:py-3 tw:text-sm tw:text-gray-500 tw:dark:text-gray-400">No notifications yet</span>
    <% end %>
  <% end %>
<% end %>
```

### `outputs/app/javascript/controllers/notifications_dropdown_controller.js`

```js
import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="notifications-dropdown"
// Open/close + click-outside is handled by the shared `ui--dropdown` controller.
// This controller is a hook for any notification-specific behaviour (e.g. POSTing
// "mark seen" when the panel opens).
export default class extends Controller {
  static targets = ['badge']
  static values = { markSeenUrl: String }

  markSeen () {
    if (!this.hasMarkSeenUrlValue) return
    fetch(this.markSeenUrlValue, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
        'Accept': 'application/json'
      }
    }).then(() => {
      if (this.hasBadgeTarget) this.badgeTarget.remove()
    })
  }
}
```

### `outputs/app/views/layouts/application.html.erb.diff` (insert in the `current_user_or_unconfirmed_user.present?` branch)

```diff
             <% if current_user_or_unconfirmed_user.present? %>
+              <li class="primary-nav-item">
+                <%= render(NotificationsDropdown::Component.new(user: current_user_or_unconfirmed_user)) %>
+              </li>
               <li class="primary-nav-item">
                 <a
                   href="#"
                   class="nav-link settings-link primary-nav-link-with-submenu"
                   id="setting_submenu"
```

## Key skill-conformance choices

- **Reused `UI::Dropdown::Component`** — already wires open/close + click-outside + Escape via `app/javascript/controllers/ui/dropdown_controller.js`.
- ViewComponent uses **keyword args** (`user:`, `limit:`) and **instance variables** (no `attr_accessor`); private methods.
- All Tailwind classes use the **`tw:` prefix**; "View all" link uses **`twlink`**.
- Unread count rendered via **`number_display(unread_count)`**.
- Template uses **`helpers.time_ago_in_words`** (path helpers unprefixed).
