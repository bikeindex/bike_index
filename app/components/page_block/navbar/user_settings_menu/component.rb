# frozen_string_literal: true

module PageBlock
  module Navbar
    module UserSettingsMenu
      # The account rows: the user's organizations, their account links and logout.
      #
      # dropdown: renders them as UI::Dropdown entries, with the trigger passed as content --
      # the org sidebar's account block. Without it they render as the navbar's gear and its
      # own <ul>, which primary_header_nav.scss styles and page-block--navbar opens, and which
      # below the navbar breakpoint sits inline in the hamburgler menu rather than behind a
      # trigger at all.
      class Component < ApplicationComponent
        # Logout is the only row that isn't somewhere to go. red-700 against the navbar's
        # near-black panel is unreadable, so that one takes the tint that carries on dark
        LOGOUT = "tw:text-red-700! tw:hover:bg-red-50! tw:hover:text-red-600!"
        LOGOUT_NAVBAR = "tw:text-red-400!"

        def initialize(current_user:, current_user_or_unconfirmed_user:, dropdown:,
          current_organization: nil, name: nil, button_class: nil, open: false)
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
          @dropdown = dropdown
          @current_organization = current_organization
          @name = name
          @button_class = button_class
          @open = open
        end

        private

        def items
          [*UserServices::MenuItemsAccount.organization_switcher(@current_user_or_unconfirmed_user,
            current_organization: @current_organization),
            link(translation(".your_registrations"), my_account_path),
            UserServices::MenuItemsAccount.marketplace_messages(@current_user),
            link(translation(".register_a_new_bike"), choose_registration_path),
            link(translation(".user_settings", user_email: @current_user_or_unconfirmed_user.email),
              edit_my_account_path, id: "navUserSettingLink",
              data: {email: @current_user_or_unconfirmed_user.email}),
            {type: :divider},
            link(translation(".logout"), goodbye_path, logout: true)].compact
        end

        def link(label, path, match: :path, matching_controllers: [], **attributes)
          {type: :link, label:, path:, match:, matching_controllers:, **attributes}
        end

        def entry(item)
          UI::ActiveLink::Component.new(text: item[:label], path: item[:path], match: item[:match],
            matching_controllers: item[:matching_controllers], data: item[:data] || {},
            id: item[:id], class: entry_class(item))
        end

        # .nav-link is the navbar's own, which the submenu's rows take with the rest of its
        # links. .twdropdown styles the entries in the sidebar, so they need nothing
        def entry_class(item)
          return (LOGOUT if item[:logout]) if @dropdown

          ["nav-link", (LOGOUT_NAVBAR if item[:logout])].compact.join(" ")
        end
      end
    end
  end
end
