module Organized
  class ImpoundRecordsController < Organized::BaseController
    include SortableTable
    before_action :set_period, only: [:index]
    before_action :find_impound_record, except: [:index]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)

      @impound_records = available_impound_records.reorder("impound_records.#{sort_column} #{sort_direction}")
                          .page(@page).per(@per_page)
                          .includes(:user, :bike, :location)
    end

    def show
      @impound_record_updates = @impound_record.impound_record_updates.reorder(created_at: :desc)
      @bike = @impound_record.bike
      @parking_notification = @impound_record.parking_notification
    end

    def update
      impound_record_update = @impound_record.impound_record_updates.create(permitted_parameters)
    end

    private

    def impound_records
      current_organization.impound_records
    end

    def sortable_columns
      %w[display_id created_at updated_at status user_id resolved_at]
    end

    def bike_search_params_present?
      @interpreted_params.except(:stolenness).values.any? || @selected_query_items_options.any? || params[:email].present?
    end

    def available_impound_records
      return @available_impound_records if defined?(@available_impound_records)
      if params[:search_status].blank? || params[:search_status] == "active"
        @search_status = "active"
        a_impound_records = impound_records.active
      elsif params[:search_status] == "all"
        @search_status = "all"
        a_impound_records = impound_records
      else
        @search_status = ImpoundRecord.statuses.include?(params[:search_status]) ? params[:search_status] : "all"
        a_impound_records = impound_records.where(status: @search_status)
      end

      if bike_search_params_present?
        bikes = a_impound_records.bikes.search(@interpreted_params)
        bikes = bikes.organized_email_search(params[:email]) if params[:email].present?
        a_impound_records = a_impound_records.where(bike_id: bikes.pluck(:id))
      end

      @available_impound_records = a_impound_records.where(created_at: @time_range)
    end

    def find_impound_record
      @impound_record = impound_records.find(params[:id])
    end

    def permitted_parameters
      params.require(:impound_record_update)
            .permit(:kind, :notes, :location_id, :transfer_email)
            .merge(user_id: current_user.id)
    end
  end
end
