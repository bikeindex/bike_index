# frozen_string_literal: true

module MarketplaceListingPanel
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(MarketplaceListingPanel::Component.new(marketplace_listing:, current_user:))
    end

    private

    def current_user
      User.find(ENV["LOOKBOOK_USER_ID"])
    end

    def marketplace_listing
      MarketplaceListing.last
    end
  end
end
