module Organized
  class BikesController < Organized::BaseController
    def index
      @bikes_count = current_organization.bikes.count
      page = params[:page] || 1
      @per_page = params[:per_page] || 25
      if current_organization.is_paid
        @bikes = current_organization.bikes.order('created_at desc')
      else
        @bikes = current_organization.bikes.order('created_at desc').page(page).per(@per_page)
      end
    end

    def new
    end

    private

    def current_index_path
      organization_bikes_path(organization_id: current_organization.to_param)
    end
  end
end
