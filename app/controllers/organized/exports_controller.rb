module Organized
  class ExportsController < Organized::BaseController
    before_action :ensure_access_to_exports!
    before_action :find_export, except: %i[index new create]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @exports = exports.order(created_at: :desc).page(@page).per(@per_page)
    end

    def show
      @avery_export_redirect = params[:avery_redirect].present?
      redirect_to @export.avery_export_url if @avery_export_redirect && @export.avery_export_url.present?
    end

    def new
      @export ||= Export.new
    end

    def create
      if ActiveRecord::Type::Boolean.new.type_cast_from_database(params.dig(:export, :avery_export))
        create_avery_export
      else
        @export = Export.new(permitted_parameters)
      end
      if flash[:error].blank? && @export.update_attributes(kind: "organization", organization_id: active_organization.id, user_id: current_user.id)
        OrganizationExportWorker.perform_async(@export.id)
        if @export.avery_export? # Send to the show page, with avery export parameter set so we can redirect when the processing is finished
          flash[:success] = "Export Created. Once it's finished processing you will be automatically directed to download the Avery labels"
          redirect_to organization_export_path(organization_id: active_organization.to_param, id: @export.id, avery_redirect: true)
        else
          flash[:success] = "Export Created. Please wait for it to finish processing to be able to download it"
          redirect_to organization_exports_path(organization_id: active_organization.to_param)
        end
      else
        @export ||= Export.new
        render :new
      end
    end

    def update
      if params[:remove_bike_codes] && @export.assign_bike_codes?
        @export.remove_bike_codes_and_record!
        flash[:success] = "Bike codes removed!"
      else
        flash[:error] = "Unknown update action!"
      end
      redirect_to organization_export_path(organization_id: active_organization.to_param, id: @export.id)
    end

    def destroy
      @export.remove_bike_codes
      @export.destroy
      flash[:success] = "export was successfully deleted!"
      redirect_to organization_exports_path(organization_id: active_organization.to_param)
    end

    private

    def create_avery_export
      if active_organization.paid_for?("avery_export")
        @export = Export.new(avery_export_parameters)
        bike_code = active_organization.bike_codes.lookup(@export.bike_code_start) if @export.bike_code_start.present?
        if bike_code.present? && bike_code.claimed?
          flash[:error] = "That sticker has already been assigned! Please choose a new initial Sticker"
        end
      else
        flash[:error] = "You don't have permission to make that sort of export! Please contact support@bikeindex.org"
      end
    end

    def permitted_parameters
      params.require(:export).permit(:timezone, :start_at, :end_at, :file_format, :custom_bike_ids, headers: [])
    end

    def avery_export_parameters
      params.require(:export).permit(:timezone, :start_at, :end_at, :bike_code_start, :custom_bike_ids)
            .merge(avery_export: true)
    end

    def find_export
      @export = exports.find(params[:id])
    end

    def exports
      Export.where(organization_id: active_organization.id, kind: "organization")
    end

    def ensure_access_to_exports!
      return true if active_organization.paid_for?("csv_exports") || current_user.superuser?
      flash[:error] = "Your organization doesn't have access to that, please contact Bike Index support"
      redirect_to organization_bikes_path(organization_id: active_organization.to_param) and return
    end
  end
end
