# frozen_string_literal: true

module PageBlock
  module MainContent
    module Organized
      # The organization admin shell - the left menu, and the content column it's
      # positioned over
      class Component < ApplicationComponent
        def initialize(current_organization:, current_user:, passive_organization:,
          show_general_alert:, controller_namespace:, controller_name:, action_name:,
          old_register_view: false, register_flow_organization_id: nil)
          @current_organization = current_organization
          @current_user = current_user
          @passive_organization = passive_organization
          @show_general_alert = show_general_alert
          @controller_namespace = controller_namespace
          @controller_name = controller_name
          @action_name = action_name
          @old_register_view = old_register_view
          @register_flow_organization_id = register_flow_organization_id
        end

        private

        def menu_items
          Org::MenuItems::Component.new(organization: @current_organization, current_user: @current_user,
            controller_namespace: @controller_namespace, controller_name: @controller_name,
            action_name: @action_name, old_register_view: @old_register_view,
            register_flow_organization_id: @register_flow_organization_id)
        end

        # The dashboard itself shows the link, even for an organization without the feature
        def show_overview_dashboard?
          @current_organization.overview_dashboard? ||
            (@controller_name == "dashboard" && @action_name == "index")
        end
      end
    end
  end
end
