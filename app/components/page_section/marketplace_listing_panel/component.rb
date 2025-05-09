# frozen_string_literal: true

module PageSection::MarketplaceListingPanel
  class Component < ApplicationComponent
    def initialize(marketplace_listing: nil)
      @marketplace_listing = marketplace_listing
    end

    def render?
      @marketplace_listing.present?
    end
  end
end
