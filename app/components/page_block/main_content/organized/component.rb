# frozen_string_literal: true

module PageBlock
  module MainContent
    module Organized
      # The organization admin shell - the content column PageBlock::Navbar::OrgSidebar sits
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
      end
    end
  end
end
