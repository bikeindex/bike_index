module Organized
  class ModelAuditsController < Organized::BaseController
    include SortableTable
    before_action :ensure_access_to_model_audits!
    before_action :set_period, only: [:index]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @organization_model_audits = organization_model_audits
        .reorder("#{scoped_sort_column} #{sort_direction}")
        .page(@page).per(@per_page)
    end

    # NOTE: This is really "create model_attestation" -
    def create
      redirect_back(fallback_location: organized_model_audits_path(organization_id: current_organization.to_param))
    end

    private

    def sortable_columns
      %w[last_bike_created_at bikes_count certification_status mnfg_name frame_model]
    end

    def permitted_parameters
      params.require(:model_attestation).permit(:kind, :url, :info)
        .merge(user_id: current_user.id, organization_id: current_organization.id)
    end

    def scoped_sort_column
      if %w[mnfg_name frame_model].include?(sort_column)
        "model_audits.#{sort_column}"
      else
        "organization_model_audits.#{sort_column}"
      end
    end

    def organization_model_audits
      organization_model_audits = OrganizationModelAudit.where(organization_id: current_organization.id)
      @time_range_column = "last_bike_created_at"
      unless InputNormalizer.boolean(params[:search_0])
        organization_model_audits = organization_model_audits.where.not(bikes_count: 0)
      end
      organization_model_audits.where(@time_range_column => @time_range)
        .joins(:model_audit)
    end

    def ensure_access_to_model_audits!
      return true if current_organization.enabled?("model_audits") || current_user.superuser?
      raise_do_not_have_access!
    end
  end
end
