# frozen_string_literal: true

module PageBlock
  module MarketplaceListingPanel
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(PageBlock::MarketplaceListingPanel::Component.new(marketplace_listing:))
      end

      # No motorized listing exists in seed data, so borrow one to show the shipping exclusion
      def not_shippable
        listing = marketplace_listing
        listing.item = Bike.motorized.first
        render(PageBlock::MarketplaceListingPanel::Component.new(marketplace_listing: listing))
      end

      private

      def marketplace_listing
        MarketplaceListing.last
      end
    end
  end
end
