class Admin::ModelAttestationsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    @per_page = params[:per_page] || 50
    @model_attestations =
      matching_model_attestations
        .includes(:model_audit, :user, :organization)
        .reorder("model_attestations.#{sort_column} #{sort_direction}")
        .page(page)
        .per(@per_page)
  end

  helper_method :matching_model_attestations

  protected

  def sortable_columns
    %w[created_at updated_at model_audit_id user_id organization_id]
  end

  def earliest_period_date
    Time.at(1528767966) # First Model Audit
  end

  def matching_model_attestations
    model_audits = ModelAudit
    if current_organization.present?
      model_audits = model_audits.where(organization_id: current_organization.id)
    end

    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    model_audits.where(@time_range_column => @time_range)
  end
end
