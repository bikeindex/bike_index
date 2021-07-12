class Admin::ImpoundRecordsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]
  before_action :find_impound_record, except: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @impound_records = matching_impound_records.includes(:user, :organization, :bike)
      .order(sort_column + " " + sort_direction)
      .page(page).per(per_page)
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
        impound_records.send(@search_status)
      end
    end

    impound_records = impound_records.where(organization_id: current_organization.id) if current_organization.present?
    impound_records.where(created_at: @time_range)
  end

  def find_impound_record
    @impound_record = ImpoundRecord.friendly_find(params[:id])
  end
end
