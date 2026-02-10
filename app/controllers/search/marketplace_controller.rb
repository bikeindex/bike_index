# frozen_string_literal: true

class Search::MarketplaceController < ApplicationController
  MAX_INDEX_PAGE = 100
  DEFAULT_DISTANCE = 50
  before_action :render_ad
  before_action :set_interpreted_params
  around_action :set_reading_role

  def index
    @render_results = Binxtils::InputNormalizer.boolean(params[:search_no_js]) || turbo_request?
    @is_marketplace = true

    if @render_results
      @pagy, @bikes = pagy(:countish, searched_bikes.reorder("marketplace_listings.published_at DESC"),
        limit: 12, page: @page, max_pages: MAX_INDEX_PAGE)
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def counts
    render json: {
      for_sale: searched_bikes_not_proximity.count, for_sale_proximity: searched_bikes_proximity.count
    }
  end

  private

  def permitted_scopes
    %w[for_sale for_sale_proximity].freeze
  end

  def searched_bikes
    @interpreted_params[:bounding_box].blank? ? searched_bikes_not_proximity : searched_bikes_proximity
  end

  def searched_bikes_not_proximity
    bikes = Bike.search(@interpreted_params).for_sale

    # Not doing anything with currency yet, so always use default
    @currency = Currency.default
    @price_min_amount = amount_for(listing_search_params[:price_min_amount])
    @price_max_amount = amount_for(listing_search_params[:price_max_amount])

    MarketplaceListing.search(bikes, price_min_amount: @price_min_amount, price_max_amount: @price_max_amount)
  end

  def searched_bikes_proximity
    searched_bikes_not_proximity.within_bounding_box(@interpreted_params[:bounding_box])
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
    @marketplace_scope = permitted_scopes.include?(params[:marketplace_scope]) ? params[:marketplace_scope] : permitted_scopes.first
    if @marketplace_scope == "for_sale_proximity" || action_name == "counts"
      @interpreted_params.merge!(proximity_hash)
    end

    @page = permitted_page(max: MAX_INDEX_PAGE)
    @search_kind = :marketplace
    @result_view = SearchResults::Container::Component
      .permitted_result_view(params[:search_result_view], default: :thumbnail)
  end

  def permitted_search_params
    # Switching to for_sale will get location, but it doesn't currently work
    params.permit(*Bike.permitted_search_params).merge(stolenness: "all")
  end

  def listing_search_params
    params.permit(:currency, :price_min_amount, :price_max_amount)
  end

  def amount_for(value)
    return nil if value.blank?

    value.to_f
  end

  def render_ad
    @ad = true
  end
end
