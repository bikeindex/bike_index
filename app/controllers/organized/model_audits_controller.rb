module Organized
  class ModelAuditsController < Organized::BaseController
    include SortableTable
    before_action :ensure_access_to_model_audits!
    before_action :set_period, only: [:index]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @organization_model_audits = ordered_organization_model_audits
        .page(@page).per(@per_page)
    end

    def update
      if params[:remove_bike_stickers] && @export.assign_bike_codes?
        @export.remove_bike_stickers_and_record!(current_user)
        flash[:success] = translation(:bike_stickers_removed)
      else
        flash[:error] = translation(:unknown_update_action)
      end
      redirect_to organization_export_path(organization_id: current_organization.to_param, id: @export.id)
    end

    private

    def sortable_columns
      %w[last_bike_created_at bikes_count certification_status manufacturer_id frame_model]
    end

    def permitted_parameters
      params.require(:model_attestation).permit(:kind)
        .merge(user_id: current_user.id, organization_id: current_organization.id)
    end

    def ordered_organization_model_audits
      organization_model_audits
    end

    def organization_model_audits
      organization_model_audits = OrganizationModelAudit.where(organization_id: current_organization.id)
      @time_range_column = "last_bike_created_at"
      organization_model_audits.where(@time_range_column => @time_range)
        .includes(:model_audit, :model_attestations)
    end

    def ensure_access_to_model_audits!
      return true if current_organization.enabled?("model_audits") || current_user.superuser?
      raise_do_not_have_access!
    end
  end
end
