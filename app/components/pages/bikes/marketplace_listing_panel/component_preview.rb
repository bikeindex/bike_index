# frozen_string_literal: true

module Pages
  module Bikes
    module MarketplaceListingPanel
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Bikes::MarketplaceListingPanel::Component.new(marketplace_listing:))
        end

        # Seed data has no standard e-bike, so motorize one in memory.
        # The shipping row needs :marketplace_shipping enabled for the listing's seller
        def not_shippable
          listing = marketplace_listing
          listing.item.propulsion_type = "throttle"
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
