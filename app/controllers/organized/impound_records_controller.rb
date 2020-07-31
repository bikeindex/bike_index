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
      @render_chart = ParamsNormalizer.boolean(params[:render_chart])

      @impound_records = available_impound_records.reorder("impound_records.#{sort_column} #{sort_direction}")
        .page(@page).per(@per_page)
        .includes(:user, :bike, :location)
    end

    def show
    end

    def update
      @impound_record_update = @impound_record.impound_record_updates.new(permitted_parameters)
      if @impound_record_update.save
        redirect_to organization_impound_record_path(@impound_record.display_id, organization_id: current_organization.to_param)
      else
        flash[:error] = @impound_record_update.errors.full_messages
        render :show
      end
    end

    helper_method :available_impound_records

    private

    def impound_records
      current_organization.impound_records
    end

    def sortable_columns
      %w[display_id created_at updated_at user_id resolved_at]
    end

    def bike_search_params_present?
      @interpreted_params.except(:stolenness).values.any? || @selected_query_items_options.any? || params[:search_email].present?
    end

    def available_impound_records
      return @available_impound_records if defined?(@available_impound_records)
      if params[:search_status] == "all"
        @search_status = "all"
        a_impound_records = impound_records
      else
        @search_status = ImpoundRecord.statuses.include?(params[:search_status]) ? params[:search_status] : "current"
        a_impound_records = impound_records.where(status: @search_status)
      end

      if bike_search_params_present?
        bikes = a_impound_records.bikes.search(@interpreted_params)
        bikes = bikes.organized_email_search(params[:search_email]) if params[:search_email].present?
        a_impound_records = a_impound_records.where(bike_id: bikes.pluck(:id))
      elsif params[:search_bike_id].present?
        a_impound_records = a_impound_records.where(bike_id: params[:search_bike_id])
      end

      @available_impound_records = a_impound_records.where(created_at: @time_range)
    end

    def find_impound_record
      # NOTE: Uses display_id, not normal id, unless id starts with pkey-
      @impound_record = if params[:id].start_with?("pkey-")
        impound_records.find_by_id(params[:id].gsub("pkey-", ""))
      else
        impound_records.find_by_display_id(params[:id])
      end
      raise ActiveRecord::RecordNotFound unless @impound_record.present?
    end

    def permitted_parameters
      params.require(:impound_record_update)
        .permit(:kind, :notes, :location_id, :transfer_email)
        .merge(user_id: current_user.id)
    end
  end
end
