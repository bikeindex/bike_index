class Admin::ImpoundRecordsController < Admin::BaseController
  include SortableTable

  before_action :set_period, only: [:index]
  before_action :find_payment, only: %i[edit update]

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

  def matching_impound_records
    return @matching_impound_records if defined?(@matching_impound_records)
    impound_records = ImpoundRecord
    impound_records.resolved if sort_column == "resolved_at"
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
    impound_records = impound_records.where(organization_id: current_organization.id) if current_organization.present?
    @matching_impound_records = impound_records.where(created_at: @time_range)
  end
end
