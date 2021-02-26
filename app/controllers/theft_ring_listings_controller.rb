class TheftRingListingsController < ApplicationController
  include SortableTable

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @theft_ring_listings = matching_theft_ring_listings
      .reorder("theft_ring_listings.#{sort_column} #{sort_direction}")
      .page(page).per(per_page)
    @selected_query_items_options = TheftRingListing.selected_query_items_options(@interpreted_params)
  end

  private

  def sortable_columns
    %w[listed_at amount_cents mnfg_name]
  end

  def permitted_search_params
    params.permit(*TheftRingListing.permitted_search_params)
  end

  def matching_theft_ring_listings
    # This might become more sophisticated someday...
    theft_ring_listings = TheftRingListing
    theft_ring_listings.search(@interpreted_params)
  end
end
