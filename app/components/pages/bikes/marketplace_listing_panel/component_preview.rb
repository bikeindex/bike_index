# frozen_string_literal: true

module Pages
  module Bikes
    module MarketplaceListingPanel
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Bikes::MarketplaceListingPanel::Component.new(marketplace_listing:))
        end

        private

        def marketplace_listing
          MarketplaceListing.last
        end
      end
    end
  end
end
