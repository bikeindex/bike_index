module Organized
  class ImpoundRecordsController < Organized::BaseController
    include SortableTable

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      search_organization_bikes
    end

    def show; end

    private

    def search_organization_bikes
      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      bikes = current_organization.impounded_bikes
      @bikes = bikes.reorder("bikes.#{sort_column} #{sort_direction}").page(@page).per(@per_page)
      if @interpreted_params[:serial]
        @close_serials = organization_bikes.search_close_serials(@interpreted_params).limit(25)
      end
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)
    end
  end
end
