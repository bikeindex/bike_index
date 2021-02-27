class StolenBikeListingsController < ApplicationController
  include SortableTable

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @stolen_bike_listings = matching_stolen_bike_listings
      .reorder("stolen_bike_listings.#{sort_column} #{sort_direction}")
      .page(page).per(per_page)
    @selected_query_items_options = StolenBikeListing.selected_query_items_options(@interpreted_params)
  end

  helper_method :matching_stolen_bike_listings

  private

  def sortable_columns
    %w[listed_at amount_cents mnfg_name]
  end

  def permitted_search_params
    params.permit(*StolenBikeListing.permitted_search_params)
      .merge(stolenness: "all")
  end

  def matching_stolen_bike_listings
    @interpreted_params = StolenBikeListing.searchable_interpreted_params(permitted_search_params)
    # This might become more sophisticated someday...
    matching_stolen_bike_listings = StolenBikeListing.search(@interpreted_params)
    @matching_stolen_bike_listings = matching_stolen_bike_listings
  end
end
