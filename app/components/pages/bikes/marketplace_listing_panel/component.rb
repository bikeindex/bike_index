# frozen_string_literal: true

module Pages
  module Bikes
    module MarketplaceListingPanel
      class Component < ApplicationComponent
        def initialize(marketplace_listing: nil)
          @marketplace_listing = marketplace_listing
        end

        def render?
          @marketplace_listing.present?
        end

        private

        def bike_type
          @marketplace_listing.item_type_display.downcase
        end

        # Motorized reads first because it's the harder no - a battery is never going in a box,
        # where an unsupported cycle type is only "not yet"
        def shipping_unavailable_reason_key
          return if @marketplace_listing.shippable?

          @marketplace_listing.item&.motorized? ? "shipping_motorized" : "shipping_cycle_type"
        end
      end
    end
  end
end
