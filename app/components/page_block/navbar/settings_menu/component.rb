# frozen_string_literal: true

module PageBlock
  module Navbar
    module SettingsMenu
      # The gear dropdown: the user's organizations, their account links and logout
      class Component < ApplicationComponent
        def initialize(current_user:, current_user_or_unconfirmed_user:)
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
        end

        private

        def items
          [*UserServices::AccountMenuItems.organization_switcher(@current_user_or_unconfirmed_user),
            {label: translation(".your_registrations"), path: my_account_path},
            UserServices::AccountMenuItems.marketplace_messages(@current_user),
            {label: translation(".register_a_new_bike"), path: choose_registration_path},
            {label: translation(".user_settings", user_email: @current_user_or_unconfirmed_user.email),
             path: edit_my_account_path,
             html_options: {id: "navUserSettingLink", data: {email: @current_user_or_unconfirmed_user.email}}},
            {type: :divider},
            {label: translation(".logout"), path: goodbye_path}].compact
        end
      end
    end
  end
end
