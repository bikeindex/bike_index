module Organized
  class BikesController < Organized::BaseController
    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      if current_organization.is_paid
        search
      else
        @bikes_count = organization_bikes.count
        @bikes = organization_bikes.order('created_at desc').page(@page).per(@per_page)
      end
    end

    def search
      @search_query_present = permitted_search_params.except(:stolenness).values.reject(&:blank?).any?
      @interpreted_params = Bike.searchable_interpreted_params(permitted_search_params, ip: forwarded_ip_address)
      bikes = organization_bikes.search(@interpreted_params)
      @bikes_count = bikes.count
      @bikes = bikes.order('created_at desc').page(@page).per(@per_page)
      if @interpreted_params[:serial]
        @close_serials = organization_bikes.search_close_serials(@interpreted_params).limit(25)
      end
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)
      render :search
    end

    def new
    end

    helper_method :stolenness

    private

    def permitted_search_params
      params.permit(*Bike.permitted_search_params).merge(stolenness: stolenness)
    end

    def stolenness
      if params['stolenness'].present?
        params['stolenness']
      else
        'all'
      end
    end

    def organization_bikes
      current_organization.bikes.reorder('bikes.created_at desc')
    end

    def current_index_path
      organization_bikes_path(organization_id: current_organization.to_param)
    end
  end
end
