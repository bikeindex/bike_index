module Organized
  class ImpoundRecordsController < Organized::BaseController
    include SortableTable

    before_action :find_impound_record, except: [:index]

    def index
      @per_page = params[:per_page] || 25
      @interpreted_params = BikeSearchable.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      @selected_query_items_options = BikeSearchable.selected_query_items_options(@interpreted_params)

      @pagy, @impound_records = pagy(available_impound_records.reorder("impound_records.#{sort_column} #{sort_direction}")
        .includes(:user, :bike, :location), limit: @per_page, page: permitted_page)
    end

    def show
      @approved_impound_claim = @impound_record.impound_claims.approved.first
    end

    def update
      return multi_update_response(params[:ids].as_json) if params[:id] == "multi_update"
      @impound_record_update = @impound_record.impound_record_updates.new(permitted_parameters)
      is_valid_kind = @impound_record.update_kinds.include?(@impound_record_update.kind)
      if @impound_record.update_kinds.include?(@impound_record_update.kind) && @impound_record_update.save
        flash[:success] = "Recorded #{@impound_record_update.kind_humanized}"
        redirect_to organization_impound_record_path(@impound_record.display_id, organization_id: current_organization.to_param)
      else
        flash[:error] = if is_valid_kind
          @impound_record_update.errors.full_messages
        else
          "Sorry, you can't update this impound record with #{@impound_record_update.kind_humanized}"
        end
        render :show
      end
    end

    helper_method :available_impound_records, :available_statuses

    private

    def impound_records
      current_organization.impound_records
    end

    def sortable_columns
      %w[created_at display_id_integer updated_at user_id resolved_at location_id]
    end

    def available_statuses
      # current ordered the way we want to display
      return @available_statuses if defined?(@available_statuses)
      available_statuses = %w[current resolved all] + (ImpoundRecord.statuses - ["current"])
      available_statuses -= ["expired"] unless current_organization.fetch_impound_configuration.expiration?
      @available_statuses = available_statuses
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
        @search_status = available_statuses.include?(params[:search_status]) ? params[:search_status] : available_statuses.first
        a_impound_records = if ImpoundRecord.statuses.include?(@search_status)
          impound_records.where(status: @search_status)
        else
          impound_records.public_send(@search_status)
        end
      end

      if %w[only_unregistered only_registered].include?(params[:search_unregisteredness])
        @search_unregisteredness = params[:search_unregisteredness]
        a_impound_records = if @search_unregisteredness == "only_registered"
          a_impound_records.registered_bike
        else
          a_impound_records.unregistered_bike
        end
      end
      @search_unregisteredness ||= "all"

      if bike_search_params_present?
        bikes = a_impound_records.bikes.search(@interpreted_params)
        bikes = bikes.organized_email_and_name_search(params[:search_email]) if params[:search_email].present?
        a_impound_records = a_impound_records.where(bike_id: bikes.pluck(:id))
      elsif params[:search_bike_id].present?
        a_impound_records = a_impound_records.where(bike_id: params[:search_bike_id])
      end

      @available_impound_records = a_impound_records.where(created_at: @time_range)
    end

    def find_impound_record
      return if params[:id] == "multi_update" # Can't find a single impound_record!
      # NOTE: Uses display_id, not normal id, unless id starts with pkey-
      @impound_record = impound_records.friendly_find!(params[:id])
    end

    def permitted_parameters
      params.require(:impound_record_update)
        .permit(:kind, :notes, :location_id, :transfer_email)
        .merge(user_id: current_user.id)
    end

    def multi_update_response(ids)
      # Parse the ids, in the variety of formats they may arrive in (duplicates parking_notifications controller)
      ids_array = ids if ids.is_a?(Array)
      ids_array = ids.keys if ids.is_a?(Hash) # parameters submitted look like this ids: { "12" => "12" }
      ids_array ||= ids.to_s.split(",")
      ids_array = ids_array.map { |id| id.strip.to_i }.reject(&:blank?)

      selected_records = impound_records.where(id: ids_array)
      if selected_records.none?
        flash[:error] = "No impound records selected for update!"
      else
        successful = selected_records.select { |impound_record|
          next unless impound_record.update_multi_kinds.include?(permitted_parameters[:kind])
          impound_record.impound_record_updates.create(permitted_parameters)
        }
        flash[:success] = "Updated #{successful.count} impound record"
      end
      redirect_back(fallback_location: organization_impound_records_path(organization_id: current_organization.to_param))
    end
  end
end
