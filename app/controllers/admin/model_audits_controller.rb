class Admin::ModelAuditsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    @per_page = params[:per_page] || 50
    @model_audits =
      matching_model_audits
        .includes(:organization_model_audits, :model_attestations)
        .reorder("model_audits.#{sort_column}" + " " + sort_direction)
        .page(page)
        .per(@per_page)
  end

  helper_method :matching_model_audits

  protected

  def sortable_columns
    %w[created_at updated_at bikes_count mnfg_name frame_model]
  end

  def earliest_period_date
    Time.at(1528767966) # First Model Audit
  end

  def matching_model_audits
    model_audits = ModelAudit
    if params[:search_mnfg_name].present?
      model_audits = model_audits.where("mnfg_name ILIKE ?", params[:search_mnfg_name])
    end
    @mnfg_other = InputNormalizer.boolean(params[:search_mnfg_other])
    model_audits = model_audits.where.not(manufacturer_other: nil) if @mnfg_other

    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    model_audits.where(@time_range_column => @time_range)
  end
end
