module Organized
  class ModelAuditsController < Organized::BaseController
    include SortableTable
    before_action :ensure_access_to_model_audits!

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @exports = available_model_audits.order(created_at: :desc).page(@page).per(@per_page)
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

    def permitted_parameters
      params.require(:model_attestation).permit(:timezone, :start_at, :end_at, :bike_code_start,
        :custom_bike_ids, :only_custom_bike_ids)
        .merge(avery_export: true)
    end

    def find_export
      @export = exports.find(params[:id])
    end

    def available_model_audits
      OrganizationModelAudit.all
    end

    def ensure_access_to_model_audits!
      return true if current_organization.enabled?("model_audits") || current_user.superuser?
      flash[:error] = translation(:your_org_does_not_have_access)
      redirect_to(organization_bikes_path(organization_id: current_organization.to_param)) && return
    end
  end
end
