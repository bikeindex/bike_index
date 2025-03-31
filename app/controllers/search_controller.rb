class SearchController < Bikes::BaseController
  MAX_INDEX_PAGE = 100
  before_action :render_ad, only: %i[index]
  before_action :enable_importmaps
  before_action :set_interpreted_params
  skip_before_action :find_bike # from Bikes::baseController
  skip_before_action :ensure_user_allowed_to_edit # from Bikes::baseController
  around_action :set_reading_role

  def index
  end

  def registrations
    @page = permitted_page(params[:page])
    @pagy, @bikes = pagy(Bike.search(@interpreted_params), limit: 10, page: @page, max_pages: MAX_INDEX_PAGE)
  end

  private

  def set_interpreted_params
    @interpreted_params = BikeSearchable.searchable_interpreted_params(permitted_search_params, ip: forwarded_ip_address)

    if params[:stolenness] == "proximity" && @interpreted_params[:stolenness] != "proximity"
      flash[:info] = translation(:we_dont_know_location, location: params[:location])
    end
    @selected_query_items_options = BikeSearchable.selected_query_items_options(@interpreted_params)
  end

  def permitted_page(page_param)
    page = (page_param.presence || 1).to_i
    page.clamp(1, MAX_INDEX_PAGE)
  end

  def render_ad
    @ad = true
  end
end
