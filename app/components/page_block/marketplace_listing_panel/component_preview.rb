# frozen_string_literal: true

module PageBlock::MarketplaceListingPanel
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(PageBlock::MarketplaceListingPanel::Component.new(marketplace_listing:))
    end

    private

    def marketplace_listing
      MarketplaceListing.last
    end
  end
end
