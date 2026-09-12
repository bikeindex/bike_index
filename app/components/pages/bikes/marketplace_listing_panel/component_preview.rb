# frozen_string_literal: true

module Pages
  module Bikes
    module MarketplaceListingPanel
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Bikes::MarketplaceListingPanel::Component.new(marketplace_listing:))
        end

        # Seed data has no e-bike, so motorize one in memory - the battery exclusion is the
        # one worth seeing, and a seeded cargo bike would show the cycle type reason instead
        def not_shippable
          listing = marketplace_listing
          listing.item = listing.item.tap { |bike| bike.propulsion_type = "throttle" }
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
