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

        # The register flow supplies its own full-bleed shell, the way it does outside the
        # sidebar - a container's gutter would leave white down either side of the gray
        def content_container
          return nil if @controller_name == "registrations" && @action_name == "new"

          helpers.organized_container
        end
      end
    end
  end
end
