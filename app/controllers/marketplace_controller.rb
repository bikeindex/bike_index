# frozen_string_literal: true

class MarketplaceController < ApplicationController
  MAX_INDEX_PAGE = 100
  before_action :render_ad
  before_action :set_interpreted_params
  around_action :set_reading_role

  def index
    @render_results = InputNormalizer.boolean(params[:search_no_js]) || turbo_request?
    @is_marketplace = true

    if @render_results
      @pagy, @bikes = pagy(
        Bike.for_sale_default_scope.search(@interpreted_params).order(published_at: :desc),
        limit: 10, page: @page, max_pages: MAX_INDEX_PAGE
      )
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def set_interpreted_params
    @interpreted_params = BikeSearchable.searchable_interpreted_params(permitted_search_params, ip: forwarded_ip_address)

    @page = permitted_page(params[:page])
    @selected_query_items_options = BikeSearchable.selected_query_items_options(@interpreted_params)
  end

  def permitted_search_params
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
