# frozen_string_literal: true

module SharedBlocks
  module MainContent
    module Organized
      # The organization admin shell - the content column SharedBlocks::Navbar::OrgSidebar sits
      # beside, and the organization-wide alerts above it
      class Component < ApplicationComponent
        def initialize(current_organization:, current_user:, passive_organization:,
          show_general_alert:, controller_name:, action_name:)
          @current_organization = current_organization
          @current_user = current_user
          @passive_organization = passive_organization
          @show_general_alert = show_general_alert
          @controller_name = controller_name
          @action_name = action_name
        end

        private

        # Cookie name is shared with app/javascript/controllers/org/pos_callout_controller.js,
        # which is what writes it
        def pos_callout_dismissed?
          request.cookies["dismissed_pos_callout_organization_ids"].to_s.split(",")
            .include?(@current_organization.id.to_s)
        end
      end
    end
  end
end
