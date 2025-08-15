# frozen_string_literal: true

module PageSection::MarketplaceListingPanel
  class Component < ApplicationComponent
    def initialize(marketplace_listing: nil)
      @marketplace_listing = marketplace_listing
    end

    def render?
      @marketplace_listing.present?
    end

    private

    def still_for_sale_if_show
      still_for_sale_at = @marketplace_listing.still_for_sale_at
      return if still_for_sale_at.blank? || @marketplace_listing.published_at.blank? ||
        still_for_sale_at < (@marketplace_listing.published_at + 1.day)

      still_for_sale_at
    end
  end
end
