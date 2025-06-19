# frozen_string_literal: true

class Search::MarketplaceController < ApplicationController
  MAX_INDEX_PAGE = 100
  DEFAULT_DISTANCE = 50
  before_action :render_ad
  before_action :set_interpreted_params
  around_action :set_reading_role

  def index
    @render_results = InputNormalizer.boolean(params[:search_no_js]) || turbo_request?
    @is_marketplace = true

    if @render_results
      @pagy, @bikes = pagy(searched_bikes.order(published_at: :desc),
        limit: 10, page: @page, max_pages: MAX_INDEX_PAGE)
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def permitted_scopes
    %w[for_sale for_sale_proximity].freeze
  end

  def searched_bikes
    bikes = Bike.search(@interpreted_params).for_sale

    if @marketplace_scope == "for_sale_proximity"
      @interpreted_params.merge!(proximity_hash)

      if @interpreted_params[:bounding_box].present?
        return bikes.within_bounding_box(@interpreted_params[:bounding_box])
      end
    end
    bikes
  end

  def proximity_hash
    location, coordinates = BikeSearchable.search_location(params[:location], forwarded_ip_address)
    return {} if location.blank?

    distance = GeocodeHelper.permitted_distance(params[:distance], default_distance: DEFAULT_DISTANCE)
    bounding_box = if coordinates.present?
      GeocodeHelper.bounding_box(coordinates, distance)
    else
      GeocodeHelper.bounding_box(location, distance)
    end
    {distance:, location:, bounding_box:}
  end

  def set_interpreted_params
    @interpreted_params = BikeSearchable.searchable_interpreted_params(permitted_search_params, ip: forwarded_ip_address)

    @page = permitted_page(params[:page])
    @selected_query_items_options = BikeSearchable.selected_query_items_options(@interpreted_params)
    @marketplace_scope = permitted_scopes.include?(params[:marketplace_scope]) ? params[:marketplace_scope] : permitted_scopes.first
  end

  def permitted_search_params
    # Switching to for_sale will get location, but it doesn't currently work
    params.permit(*Bike.permitted_search_params).merge(stolenness: "all")
  end

  def render_ad
    @ad = true
  end

  def permitted_page(page_param)
    page = (page_param.presence || 1).to_i
    page.clamp(1, MAX_INDEX_PAGE)
  end
end
