# frozen_string_literal: true

module PageBlock
  module Navbar
    module PrimaryMenu
      # The navbar's main menu, rendered from a manifest of items rather than repeated markup
      class Component < ApplicationComponent
        # Replaces UI::Dropdown's button classes entirely -- the gear is a navbar row, and
        # .settings-link in primary_header_nav.scss sizes the svg inside it. Shown at every
        # width: below the navbar breakpoint this row is inside the open hamburgler menu,
        # and it is the only way to reach the account links there
        SETTINGS_BUTTON = "settings-link tw:block tw:px-[15px] tw:py-1.5"

        def initialize(current_user:, current_user_or_unconfirmed_user:)
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
        end

        private

        def menu_items
          [search_item("d-lg-none"),
            marketplace_item("d-lg-none"),
            {type: :divider, item_class: "d-lg-none"},
            *account_items,
            {label: translation(".help"), path: help_path},
            {label: translation(".stolen_bike"), path: get_your_stolen_bike_back_path},
            {label: translation(".donate"), path: why_donate_path},
            {label: translation(".blog"), path: news_index_path, match: :controller},
            marketplace_item("d-lg-block"),
            search_item("d-none d-lg-block")]
        end

        # Active anywhere in the registration search — any stolenness, a query, page 2 — so the
        # route is what matches, not the stolenness this happens to link to
        def search_item(item_class)
          {label: translation(".search"), path: helpers.default_bike_search_path,
           match: :controller_action, item_class:}
        end

        def marketplace_item(item_class)
          {label: translation(".marketplace"), path: search_marketplace_path,
           match: :controller_action, item_class:}
        end

        def account_items
          return [{type: :settings}, {type: :divider}] if @current_user_or_unconfirmed_user.present?

          [{label: translation(".sign_up"), path: new_user_url, link_class: "signup-link"},
            {label: translation(".log_in"), path: new_session_url}]
        end

        def settings_menu
          PageBlock::Navbar::UserSettingsMenu::Component.new(current_user: @current_user,
            current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user,
            name: translation(".settings_menu"), button_class: SETTINGS_BUTTON)
        end
      end
    end
  end
end
