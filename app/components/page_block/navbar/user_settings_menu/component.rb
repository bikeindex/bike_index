# frozen_string_literal: true

module PageBlock
  module Navbar
    module UserSettingsMenu
      # The account rows: the user's organizations, their account links and logout. The
      # navbar hangs them off its gear and the org sidebar off its account block, so the
      # trigger is the caller's and only the rows are here.
      class Component < ApplicationComponent
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

        def link(label, path, **attributes)
          {type: :link, label:, path:, **attributes}
        end
      end
    end
  end
end
