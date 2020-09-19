module OrgPublic
  class ImpoundedBikesController < OrgPublic::BaseController
    include SortableTable
    before_action :ensure_public_impound_bikes!
    before_action :set_period, only: [:index]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)

      @impound_records = available_impound_records.reorder("impound_records.#{sort_column} #{sort_direction}")
        .page(@page).per(@per_page)
        .includes(:bike, :location)
    end

    private

    def ensure_public_impound_bikes!
      # It will 404 if there isn't an current_organization because of OrgPublic before action
      return false unless current_organization.present?
      if current_organization.enabled?("impound_bikes")
        return true if current_organization.public_impound_bikes?
        if current_user&.authorized?(current_organization)
          flash[:success] = "This page is not publicly visible (it's only visible to organization members)."
          return true
        end
      end
      flash[:error] = "#{current_organization.short_name} doesn't have that feature enabled, please email support@bikeindex.org if this is a surprise"
      redirect_to user_root_url && return
    end


    def sortable_columns
      %w[created_at display_id location_id]
    end

    def bike_search_params_present?
      @interpreted_params.except(:stolenness).values.any? || @selected_query_items_options.any? || params[:search_email].present?
    end

    def available_impound_records
      return @available_impound_records if defined?(@available_impound_records)
      a_impound_records = current_organization.impound_records

      if bike_search_params_present?
        bikes = a_impound_records.bikes.search(@interpreted_params)
        bikes = bikes.organized_email_search(params[:search_email]) if params[:search_email].present?
        a_impound_records = a_impound_records.where(bike_id: bikes.pluck(:id))
      elsif params[:search_bike_id].present?
        a_impound_records = a_impound_records.where(bike_id: params[:search_bike_id])
      end

      @available_impound_records = a_impound_records.where(created_at: @time_range)
    end
  end
end
