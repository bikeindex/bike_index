module Organized
  class BikesController < Organized::BaseController
    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      if current_organization.bike_search?
        search_organization_bikes
      else
        @bikes = organization_bikes.order("bikes.created_at desc").page(@page).per(@per_page)
      end
    end

    def recoveries
      redirect_to current_index_path and return unless current_organization.show_recoveries?
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @recoveries_count = current_organization.recovered_records.count
      @recoveries = current_organization.recovered_records.order('date_recovered desc').page(@page).per(@per_page)
    end

    def new; end

    private

    def organization_bikes
      current_organization.bikes.reorder('bikes.created_at desc')
    end

    def current_index_path
      organization_bikes_path(organization_id: current_organization.to_param)
    end
  end
end
