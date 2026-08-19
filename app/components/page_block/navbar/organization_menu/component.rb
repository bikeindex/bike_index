# frozen_string_literal: true

module PageBlock
  module Navbar
    module OrganizationMenu
      # The passive organization's dropdown, between the logo and the primary menu
      class Component < ApplicationComponent
        def initialize(organization:, current_user:, controller_namespace:, controller_name:, action_name:,
          old_register_view: false, register_flow_organization_id: nil)
          @organization = organization
          @current_user = current_user
          @controller_namespace = controller_namespace
          @controller_name = controller_name
          @action_name = action_name
          @old_register_view = old_register_view
          @register_flow_organization_id = register_flow_organization_id
        end

        def render?
          @organization.present? && @current_user.present?
        end

        private

        def menu_items
          Org::MenuItems::Component.new(organization: @organization, current_user: @current_user,
            controller_namespace: @controller_namespace, controller_name: @controller_name,
            action_name: @action_name, is_dropdown: true, old_register_view: @old_register_view,
            register_flow_organization_id: @register_flow_organization_id)
        end
      end
    end
  end
end
