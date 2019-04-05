module Organized
  class BikesController < Organized::BaseController
    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @bike_code = BikeCode.lookup_with_fallback(params[:bike_code], organization_id: active_organization.id) if params[:bike_code].present?
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

    def multi_search; end

    private

    def organization_bikes
      active_organization.bikes.reorder("bikes.created_at desc")
    end

    def current_index_path
      organization_bikes_path(organization_id: active_organization.to_param)
    end

    def search_organization_bikes
      @search_query_present = permitted_org_bike_search_params.except(:stolenness).values.reject(&:blank?).any?
      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      org = active_organization || current_organization
      if org.present?
        bikes = org.bikes.reorder("bikes.created_at desc").search(@interpreted_params)
        bikes = bikes.organized_email_search(params[:email]) if params[:email].present?
      else
        bikes = Bike.reorder("bikes.created_at desc").search(@interpreted_params)
      end
      @bikes = bikes.order("bikes.created_at desc").page(@page).per(@per_page)
      if @interpreted_params[:serial]
        @close_serials = organization_bikes.search_close_serials(@interpreted_params).limit(25)
      end
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)
    end
  end
end
