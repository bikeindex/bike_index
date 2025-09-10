module Organized
  class HotSheetsController < Organized::BaseController
    before_action :ensure_admin!, except: [:show]
    before_action :ensure_access_to_hot_sheet!
    before_action :set_current_hot_sheet_configuration
    before_action :ensure_valid_hot_sheet_configuration!, only: [:show]

    def show
      @current = params[:day].blank?
      @day = @current ? nil : params[:day].to_date
      @hot_sheet = HotSheet.for(current_organization, @day)
    end

    def edit
    end

    def update
      if @hot_sheet_configuration.update(permitted_parameters)
        flash[:success] = "Hot Sheet configuration updated"
        if @hot_sheet_configuration.send_today_now?
          ProcessHotSheetJob.perform_async(current_organization.id)
        end
        redirect_back(fallback_location: organization_root_url)
      else
        flash[:error] = @hot_sheet_configuration.errors.full_messages.to_sentence
        render :edit
      end
    end

    private

    def ensure_valid_hot_sheet_configuration!
      return true if @hot_sheet_configuration&.is_on? || current_organization.search_coordinates_set?

      flash[:error] = HotSheetConfiguration::MISSING_LOCATION_ERROR
      url_to_redirect_to = current_user&.admin_of?(current_organization) ? edit_organization_hot_sheet_path(current_organization) : organization_root_url(current_organization)
      redirect_to(url_to_redirect_to) && return
    end

    def ensure_access_to_hot_sheet!
      return unless ensure_current_organization!

      # ensure_admin! passes with superuser - this allow superuser to see even if org not enabled
      return true if current_organization.enabled?("hot_sheet") || current_user.superuser?

      raise_do_not_have_access!
    end

    def set_current_hot_sheet_configuration
      @hot_sheet_configuration = current_organization.hot_sheet_configuration
      unless @hot_sheet_configuration.present?
        @hot_sheet_configuration = HotSheetConfiguration.create(organization_id: current_organization.id)
      end
      @hot_sheet_configuration
    end

    def permitted_parameters
      params.require(:hot_sheet_configuration)
        .permit([:is_on, :timezone_str, :send_hour, :search_radius_miles, :search_radius_kilometers])
    end
  end
end
