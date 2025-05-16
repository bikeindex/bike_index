# frozen_string_literal: true

module PageSection::MarketplaceListingPanel
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(PageSection::MarketplaceListingPanel::Component.new(marketplace_listing:))
    end

    private

    def marketplace_listing
      MarketplaceListing.last
    end
  end
end
