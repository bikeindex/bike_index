# frozen_string_literal: true

class MarketplaceController < ApplicationController
  def index
    @page = params[:page]
    @pagy, @marketplace_listings = pagy(searched_marketplace_listings, limit: 25, page: @page)
  end

  private

  def searched_marketplace_listings
    MarketplaceListing.for_sale.reorder(updated_at: :desc)
  end
end
