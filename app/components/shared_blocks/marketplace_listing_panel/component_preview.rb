# frozen_string_literal: true

module SharedBlocks
  module MarketplaceListingPanel
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(SharedBlocks::MarketplaceListingPanel::Component.new(marketplace_listing:))
      end

      private

      def marketplace_listing
        MarketplaceListing.last
      end
    end
  end
end
