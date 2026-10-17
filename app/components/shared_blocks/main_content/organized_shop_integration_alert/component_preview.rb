# frozen_string_literal: true

module SharedBlocks
  module MainContent
    module OrganizedShopIntegrationAlert
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Component.new(current_organization: qualifying_organization, controller_name: "dashboard",
            action_name: "index"))
        end

        def viewing_add_a_bike_page
          render(Component.new(current_organization: qualifying_organization, controller_name: "bikes",
            action_name: "new"))
        end

        private

        def qualifying_organization
          Organization.new(name: "Example Bike Shop", slug: "example-bike-shop", kind: "bike_shop", pos_kind: "no_pos")
        end
      end
    end
  end
end
