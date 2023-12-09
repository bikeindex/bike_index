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
    %w[created_at updated_at model_audit_id user_id organization_id kind]
  end

  def earliest_period_date
    Time.at(1528767966) # First Model Audit
  end

  def matching_model_attestations
    model_attestations = ModelAttestation
    if current_organization.present?
      model_attestations = model_attestations.where(organization_id: current_organization.id)
    end
    if params[:search_model_audit_id].present?
      @model_audit = ModelAudit.find(params[:search_model_audit_id])
      model_attestations = model_attestations.where(model_audit_id: @model_audit.id)
    end

    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    model_attestations.where(@time_range_column => @time_range)
  end
end
