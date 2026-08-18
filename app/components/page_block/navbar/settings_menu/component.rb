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
          [*organization_items,
            {label: translation(".your_registrations"), path: my_account_path},
            marketplace_messages_item,
            {label: translation(".register_a_new_bike"), path: choose_registration_path},
            {label: translation(".user_settings", user_email: @current_user_or_unconfirmed_user.email),
             path: edit_my_account_path,
             html_options: {id: "navUserSettingLink", data: {email: @current_user_or_unconfirmed_user.email}}},
            {type: :divider},
            {label: translation(".logout"), path: goodbye_path}].compact
        end

        def organization_items
          organizations = @current_user_or_unconfirmed_user.organization_roles.includes(:organization)
            .filter_map(&:organization)
          return [] if organizations.none?

          organizations.map { |organization|
            {label: translation(".view_org", org_name: organization.name),
             path: organization_root_path(organization_id: organization.to_param)}
          } + [{type: :divider}]
        end

        # .any_for_user? caches
        def marketplace_messages_item
          return unless MarketplaceMessage.any_for_user?(@current_user)

          {label: translation(".marketplace_messages"), path: my_account_messages_path}
        end
      end
    end
  end
end
