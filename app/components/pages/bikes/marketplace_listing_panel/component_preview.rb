# frozen_string_literal: true

module Pages
  module Bikes
    module MarketplaceListingPanel
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Bikes::MarketplaceListingPanel::Component.new(marketplace_listing:))
        end

        # No motorized listing exists in seed data, so borrow one to show the shipping exclusion
        def not_shippable
          listing = marketplace_listing
          listing.item = Bike.motorized.first
          render(Pages::Bikes::MarketplaceListingPanel::Component.new(marketplace_listing: listing))
        end

        private

        def marketplace_listing
          MarketplaceListing.last
        end
      end
    end
  end
end
