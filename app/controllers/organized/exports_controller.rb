module Organized
  class ExportsController < Organized::BaseController
    before_action :ensure_access_to_exports!
    before_action :find_export, only: %i[show destroy]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @exports = exports.order(created_at: :desc).page(@page).per(@per_page)
    end

    def show; end

    def new
      @export ||= Export.new
    end

    def create
      @export = Export.new(permitted_parameters)
      if @export.update_attributes(kind: "organization", organization_id: current_organization.id, user_id: current_user.id)
        flash[:success] = "Export Created. Please wait for it to finish processing to be able to download it"
        OrganizationExportWorker.perform_async(@export.id)
        redirect_to organization_exports_path(organization_id: current_organization.to_param)
      else
        render :new
      end
    end

    def destroy
      @export.destroy
      flash[:success] = "export was successfully deleted!"
      redirect_to organization_exports_path(organization_id: current_organization.to_param)
    end

    private

    def permitted_parameters
      params.require(:export).permit(:timezone, :start_at, :end_at, headers: [])
    end

    def find_export
      @export = exports.find(params[:id])
    end

    def exports
      Export.where(organization_id: current_organization.id, kind: "organization")
    end

    def ensure_access_to_exports!
      return true if current_organization.paid_for?("csv-exports") || current_user.superuser?
      flash[:error] = "Your organization doesn't have access to that, please contact Bike Index support"
      redirect_to organization_bikes_path(organization_id: current_organization.to_param) and return
    end
  end
end
