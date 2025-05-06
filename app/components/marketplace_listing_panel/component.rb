# frozen_string_literal: true

module MarketplaceListingPanel
  class Component < ApplicationComponent
    def initialize(marketplace_listing:, current_user: nil)
      @marketplace_listing = marketplace_listing
      @current_user = current_user
    end
  end
end
