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
      if ParamsNormalizer.boolean(params.dig(:export, :avery_export))
        create_avery_export
      else
        @export = Export.new(permitted_parameters)
        @export.options[:partial_registrations] = partial_registration_params
      end
      if flash[:error].blank? && @export.update_attributes(kind: "organization", organization_id: current_organization.id, user_id: current_user.id)
        OrganizationExportWorker.perform_async(@export.id)
        if @export.avery_export? # Send to the show page, with avery export parameter set so we can redirect when the processing is finished
          flash[:success] = translation(:with_avery_redirect)
          redirect_to organization_export_path(organization_id: current_organization.to_param, id: @export.id, avery_redirect: true)
        else
          flash[:success] = translation(:wait_to_download)
          redirect_to organization_exports_path(organization_id: current_organization.to_param)
        end
      else
        @export ||= Export.new
        render :new
      end
    end

    def update
      if params[:remove_bike_codes] && @export.assign_bike_codes?
        @export.remove_bike_codes_and_record!
        flash[:success] = translation(:bike_stickers_removed)
      else
        flash[:error] = translation(:unknown_update_action)
      end
      redirect_to organization_export_path(organization_id: current_organization.to_param, id: @export.id)
    end

    def destroy
      @export.remove_bike_codes
      @export.destroy
      flash[:success] = translation(:export_deleted)
      redirect_to organization_exports_path(organization_id: current_organization.to_param)
    end

    private

    def create_avery_export
      if current_organization.enabled?("avery_export")
        @export = Export.new(avery_export_parameters) # Note: avery export can't include partials
        bike_sticker = current_organization.bike_stickers.lookup(@export.bike_code_start) if @export.bike_code_start.present?
        if bike_sticker.present? && bike_sticker.claimed?
          flash[:error] = translation(:sticker_already_assigned)
        end
      else
        flash[:error] = translation(:do_not_have_permission)
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
      Export.where(organization_id: current_organization.id, kind: "organization")
    end

    def partial_registration_params
      return false unless current_organization.enabled?("show_partial_registrations")
      include_full = ParamsNormalizer.boolean(params[:include_full_registrations])
      include_partial = ParamsNormalizer.boolean(params[:include_partial_registrations])
      return false unless include_full || include_partial
      return "only" if !include_full && include_partial
      include_partial ? true : false
    end

    def ensure_access_to_exports!
      return true if current_organization.enabled?("csv_exports") || current_user.superuser?
      flash[:error] = translation(:your_org_does_not_have_access)
      redirect_to organization_bikes_path(organization_id: current_organization.to_param) and return
    end
  end
end
