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
      if params.dig(:export, :avery_export)
        if current_organization.paid_for?("avery_export")
          @export = avery_export
        else
          flash[:error] = "You don't have permission to make that sort of export! Please contact support@bikeindex.org"
        end
      else
        @export = Export.new(permitted_parameters)
      end
      if flash[:error].blank? && @export.update_attributes(kind: "organization", organization_id: current_organization.id, user_id: current_user.id)
        flash[:success] = "Export Created. Please wait for it to finish processing to be able to download it"
        OrganizationExportWorker.perform_async(@export.id)
        redirect_to organization_exports_path(organization_id: current_organization.to_param)
      else
        @export ||= Export.new
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
      params.require(:export).permit(:timezone, :start_at, :end_at, :file_format, headers: [])
    end

    def avery_export
      export = Export.new(params.require(:export).permit(:timezone, :start_at, :end_at).merge(file_format: :csv))
      # attributes that we set manually
      export.headers = %w[owner_name_or_email registration_address]
      export.options = export.options.merge(avery_export: true)
      export
    end

    def find_export
      @export = exports.find(params[:id])
    end

    def exports
      Export.where(organization_id: current_organization.id, kind: "organization")
    end

    def ensure_access_to_exports!
      return true if current_organization.paid_for?("csv_exports") || current_user.superuser?
      flash[:error] = "Your organization doesn't have access to that, please contact Bike Index support"
      redirect_to organization_bikes_path(organization_id: current_organization.to_param) and return
    end
  end
end
