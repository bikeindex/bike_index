class Admin::ModelAuditsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  def index
    @per_page = params[:per_page] || 50
    @pagy, @model_audits =
      pagy(matching_model_audits
        .includes(:organization_model_audits, :model_attestations)
        .reorder(sort_ordered), limit: @per_page)
  end

  helper_method :matching_model_audits

  protected

  def sortable_columns
    %w[created_at updated_at bikes_count mnfg_name frame_model]
  end

  def earliest_period_date
    Time.at(1528767966) # First Model Audit
  end

  def sort_ordered
    if %w[mnfg_name frame_model].include?(sort_column)
      ModelAudit.arel_table[sort_column].lower.send(sort_direction)
    else
      "model_audits.#{sort_column} #{sort_direction}"
    end
  end

  def matching_model_audits
    model_audits = ModelAudit
    if params[:search_mnfg_name].present?
      model_audits = model_audits.where("mnfg_name ILIKE ?", "%#{params[:search_mnfg_name]}%")
      @manufacturer = Manufacturer.friendly_find(params[:search_mnfg_name])
    end
    @mnfg_other = InputNormalizer.boolean(params[:search_mnfg_other])
    if params[:search_frame_model].present?
      model_audits = if ["unknown", "missing model"].include?(params[:search_frame_model].downcase)
        model_audits.where(frame_model: nil)
      else
        model_audits.where("frame_model ILIKE ?", params[:search_frame_model])
      end
    end
    model_audits = model_audits.where.not(manufacturer_other: nil) if @mnfg_other

    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    model_audits.where(@time_range_column => @time_range)
  end
end
