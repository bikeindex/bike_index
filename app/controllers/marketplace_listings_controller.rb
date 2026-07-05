class MarketplaceListingsController < ApplicationController
  # Public short URL (/m/<short_id>). A listing has no page of its own, so send
  # the visitor to the item it's selling.
  def show
    @marketplace_listing = MarketplaceListing.find_id(params[:id])
    redirect_to(@marketplace_listing.item)
  end
end
