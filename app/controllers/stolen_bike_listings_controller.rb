class StolenBikeListingsController < ApplicationController
  include SortableTable

  def index
    @render_info = calculated_render_info
    if @render_info
      @blog = Blog.friendly_find(Blog.theft_rings_id)
      per_page = 10
    end
    per_page ||= params[:per_page] || 25
    @pagy, @stolen_bike_listings = pagy(matching_stolen_bike_listings
      .reorder("stolen_bike_listings.#{sort_column} #{sort_direction}"), limit: per_page)

    @selected_query_items_options = StolenBikeListing.selected_query_items_options(@interpreted_params)
  end

  helper_method :matching_stolen_bike_listings

  private

  def sortable_columns
    %w[listed_at amount_cents mnfg_name]
  end

  def calculated_render_info
    # Duplicates ApplicationHelper#sortable_search_params
    sortable_search_params = params.permit(*params.keys.select { |k| k.to_s.start_with?("search_") }, # params starting with search_
      :direction, :sort, # sorting params
      :period, :start_time, :end_time, :time_range_column, :render_chart, # Time period params
      :user_id, :organization_id, :query, # General search params
      :serial, :stolenness, :location, :distance, query_items: []) # Bike searching params
    # only render info if it's present
    sortable_search_params.values.reject(&:blank?).none?
  end

  def permitted_search_params
    params.permit(*StolenBikeListing.permitted_search_params)
      .merge(stolenness: "all")
  end

  def earliest_period_date
    StolenBikeListing.minimum(:listed_at) || Time.current.beginning_of_year
  end

  def matching_stolen_bike_listings
    @interpreted_params = StolenBikeListing.searchable_interpreted_params(permitted_search_params)
    # This might become more sophisticated someday...
    matching_stolen_bike_listings = StolenBikeListing.search(@interpreted_params)

    @time_range_column = "listed_at" # Maybe will have other possibilities later
    @matching_stolen_bike_listings = matching_stolen_bike_listings.where(@time_range_column => @time_range)
  end
end
