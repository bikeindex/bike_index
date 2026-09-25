# frozen_string_literal: true

module SharedBlocks
  module MainContent
    module OrganizedShopIntegrationAlert
      # The point-of-sale integration callout shown to bike shops without a working POS
      # connection - one card per POS plus a manual-registration fallback, dismissible
      # per organization
      class Component < ApplicationComponent
        def initialize(current_organization:, controller_name:, action_name:)
          @current_organization = current_organization
          @controller_name = controller_name
          @action_name = action_name
        end

        def render?
          OrgServices::Displayer.bike_shop_display_integration_alert?(@current_organization) && !dismissed?
        end

        private

        def viewing_add_a_bike_page?
          @controller_name == "bikes" && @action_name == "new"
        end

        # Cookie name is shared with app/javascript/controllers/org/pos_callout_controller.js,
        # which is what writes it
        def dismissed?
          request.cookies["dismissed_pos_callout_organization_ids"].to_s.split(",")
            .include?(@current_organization.id.to_s)
        end
      end
    end
  end
end
