# frozen_string_literal: true

module PageBlock
  module Navbar
    module UserSettingsMenu
      # The account rows: the user's organizations, their account links and logout. The
      # navbar hangs them off its gear and the org sidebar off its account block, so the
      # trigger is the caller's and only the rows are here.
      class Component < ApplicationComponent
        # UI::Dropdown puts its active colors on the li, for an entry that knows whether it's
        # current when it renders. These resolve in the browser, so the row wears them itself
        CURRENT = "tw:is-active:bg-purple-500 tw:is-active:text-white"
        # Logout is the only row that isn't somewhere to go
        LOGOUT = "tw:text-red-700! tw:hover:bg-red-50! tw:hover:text-red-600!"

        def initialize(current_user:, current_user_or_unconfirmed_user:, name:, button_class: nil)
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
          @name = name
          @button_class = button_class
        end

        private

        def items
          [*UserServices::MenuItemsAccount.organization_switcher(@current_user_or_unconfirmed_user),
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
            id: item[:id], class: item[:logout] ? LOGOUT : CURRENT)
        end
      end
    end
  end
end
