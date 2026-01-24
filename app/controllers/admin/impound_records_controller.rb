class Admin::ImpoundRecordsController < Admin::BaseController
  include SortableTable

  before_action :find_impound_record, except: [:index]

  def index
    params[:page] || 1
    @per_page = permitted_per_page(default: 50)
    @pagy, @impound_records = pagy(:countish, matching_impound_records.includes(:user, :organization, :bike, :impound_claims)
      .order("impound_records.#{sort_column}" + " " + sort_direction), limit: @per_page, page: permitted_page)
  end

  def show
  end

  helper_method :matching_impound_records, :available_statuses

  protected

  def available_statuses
    %w[all current resolved] + (ImpoundRecord.statuses - ["current"]) # current ordered the way we want to display
  end

  def sortable_columns
    %w[created_at organization_id location_id updated_at status user_id resolved_at]
  end

  def earliest_period_date
    Time.at(1580853693) # 14 days before first impound record created
  end

  def matching_impound_records
    impound_records = ImpoundRecord

    if params[:search_status] == "all"
      @search_status = "all"
    else
      @search_status = available_statuses.include?(params[:search_status]) ? params[:search_status] : available_statuses.first
      impound_records = if ImpoundRecord.statuses.include?(@search_status)
        impound_records.where(status: @search_status)
      else
        impound_records.public_send(@search_status)
      end
    end
    @with_claims = Binxtils::InputNormalizer.boolean(params[:search_with_claims])
    impound_records = impound_records.with_claims if @with_claims
    if params[:search_bike_id].present?
      impound_records = impound_records.where(bike_id: params[:search_bike_id])
    end
    impound_records = impound_records.where(organization_id: current_organization.id) if current_organization.present?
    impound_records.where(created_at: @time_range)
  end

  def find_impound_record
    @impound_record = ImpoundRecord.friendly_find(params[:id])
    @bike = @impound_record.bike
  end
end
