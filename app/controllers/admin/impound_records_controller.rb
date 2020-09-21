class Admin::ImpoundRecordsController < Admin::BaseController
  include SortableTable

  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @impound_records = matching_impound_records.includes(:user, :organization, :bike)
      .order(sort_column + " " + sort_direction)
      .page(page).per(per_page)
  end

  helper_method :matching_impound_records

  protected

  def sortable_columns
    %w[created_at organization_id location_id updated_at status user_id resolved_at]
  end

  def earliest_period_date
    Time.at(1580853693) # 14 days before first impound record created
  end

  def matching_impound_records
    return @matching_impound_records if defined?(@matching_impound_records)
    impound_records = ImpoundRecord
    impound_records.resolved if sort_column == "resolved_at"
    if ImpoundRecord.statuses.include?(params[:search_status])
      @search_status = params[:search_status]
      impound_records = impound_records.where(status: @search_status)
    else
      @search_status = "all"
    end
    impound_records = impound_records.where(organization_id: current_organization.id) if current_organization.present?
    @matching_impound_records = impound_records.where(created_at: @time_range)
  end
end
