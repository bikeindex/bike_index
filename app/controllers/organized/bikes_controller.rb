module Organized
  class BikesController < Organized::BaseController
    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      if active_organization.paid_for?("bike_search")
        search_organization_bikes
      else
        @bikes = organization_bikes.order("bikes.created_at desc").page(@page).per(@per_page)
      end
    end

    def recoveries
      redirect_to current_index_path and return unless active_organization.paid_for?("show_recoveries")
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @recoveries = active_organization.recovered_records.order(date_recovered: :desc).page(@page).per(@per_page)
    end

    def incompletes
      redirect_to current_index_path and return unless active_organization.paid_for?("show_partial_registrations")
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      b_params = active_organization.incomplete_b_params
      b_params = b_params.email_search(params[:query]) if params[:query].present?
      @b_params = b_params.order(created_at: :desc).page(@page).per(@per_page)
    end

    def new; end

    private

    def organization_bikes
      active_organization.bikes.reorder("bikes.created_at desc")
    end

    def current_index_path
      organization_bikes_path(organization_id: active_organization.to_param)
    end
  end
end
