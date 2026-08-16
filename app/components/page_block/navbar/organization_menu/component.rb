# frozen_string_literal: true

module PageBlock
  module Navbar
    module OrganizationMenu
      # The passive organization's dropdown, between the logo and the primary menu
      class Component < ApplicationComponent
        def initialize(organization:, current_user:, unregistered_parking_notification: nil)
          @organization = organization
          @current_user = current_user
          @unregistered_parking_notification = unregistered_parking_notification
        end

        def render?
          @organization.present? && @current_user.present?
        end

        private

        def menu_items
          Org::MenuItems::Component.new(organization: @organization, current_user: @current_user,
            is_dropdown: true, unregistered_parking_notification: @unregistered_parking_notification)
        end
      end
    end
  end
end
