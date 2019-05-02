module Organized
  class BikesController < Organized::BaseController
    include SortableTable

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @bike_code = BikeCode.lookup_with_fallback(params[:bike_code], organization_id: current_organization.id) if params[:bike_code].present?
      if current_organization.paid_for?("bike_search")
        search_organization_bikes
      else
        @bikes = organization_bikes.order("bikes.created_at desc").page(@page).per(@per_page)
      end
    end

    def recoveries
      redirect_to current_index_path and return unless current_organization.paid_for?("show_recoveries")
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @recoveries = current_organization.recovered_records.order(date_recovered: :desc).page(@page).per(@per_page)
    end

    def incompletes
      redirect_to current_index_path and return unless current_organization.paid_for?("show_partial_registrations")
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      b_params = current_organization.incomplete_b_params
      b_params = b_params.email_search(params[:query]) if params[:query].present?
      @b_params = b_params.order(created_at: :desc).page(@page).per(@per_page)
    end

    def new; end

    def multi_serial_search; end

    private

    def sortable_columns
      %w[id updated_at owner_email manufacturer_id frame_model stolen]
    end

    def organization_bikes
      current_organization.bikes.reorder("bikes.created_at desc")
    end

    def current_index_path
      organization_bikes_path(organization_id: current_organization.to_param)
    end

    def search_organization_bikes
      @search_query_present = permitted_org_bike_search_params.except(:stolenness).values.reject(&:blank?).any?
      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      org = current_organization || passive_organization
      if org.present?
        bikes = org.bikes.search(@interpreted_params)
        bikes = bikes.organized_email_search(params[:email]) if params[:email].present?
      else
        bikes = Bike.search(@interpreted_params)
      end
      @search_stickers = false
      if params[:search_stickers].present?
        @search_stickers = params[:search_stickers] == "none" ? "none" : "with"
        # bikes = @search_stickers == "none" ? bikes.bike_codes()
      end
      @bikes = bikes.reorder("bikes.#{sort_column} #{sort_direction}").page(@page).per(@per_page)
      if @interpreted_params[:serial]
        @close_serials = organization_bikes.search_close_serials(@interpreted_params).limit(25)
      end
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)
    end
  end
end
