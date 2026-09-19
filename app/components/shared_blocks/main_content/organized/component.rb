# frozen_string_literal: true

module SharedBlocks
  module MainContent
    module Organized
      # The organization admin shell - the content column SharedBlocks::Navbar::OrgSidebar sits
      # beside, and the organization-wide alerts above it
      class Component < ApplicationComponent
        # nil is no container: the register flow supplies its own full-bleed shell
        PAGE_CONTAINERS = {%w[registrations new] => nil, %w[bulk_imports show] => "container-fluid"}.freeze
        FLUID_CONTROLLERS = %w[parking_notifications impound_records impound_claims graduated_notifications
          lines model_audits registrations].freeze
        JAVASCRIPT_PACK_PAGES = [%w[bikes recoveries], %w[bikes incompletes], %w[exports show], %w[exports new],
          %w[users new], %w[dashboard index], %w[impounded_bikes index]].freeze

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

        def page = [@controller_name, @action_name]

        def container
          return PAGE_CONTAINERS[page] if PAGE_CONTAINERS.key?(page)

          FLUID_CONTROLLERS.include?(@controller_name) ? "container-fluid" : "container"
        end

        def include_javascript_pack?
          container == "container-fluid" || JAVASCRIPT_PACK_PAGES.include?(page)
        end
      end
    end
  end
end
