module Organized
  class HotSheetsController < Organized::BaseController
    before_action :ensure_admin!, except: [:show]
    before_action :ensure_access_to_hot_sheet!
    before_action :set_current_hot_sheet_configuration, except: [:show]

    def show
      @current = params[:day].blank?
      @day = @current ? nil : (params[:day]).to_date
      @hot_sheet = HotSheet.for(current_organization, @day)
    end

    def edit
    end

    def update
      if @hot_sheet_configuration.update(permitted_parameters)
        flash[:success] = "Hot Sheet configuration updated"
        ProcessHotSheetWorker.perform_async(current_organization.id)
        redirect_back(fallback_location: organization_root_url)
      else
        flash[:error] = @hot_sheet_configuration.errors.full_messages.to_sentence
        render :edit
      end
    end

    private

    def ensure_access_to_hot_sheet!
      return unless ensure_current_organization!

      # ensure_admin! passes with superuser - this allow superuser to see even if org not enabled
      return true if current_user.superuser? || current_organization.enabled?("hot_sheet")

      flash[:error] = translation(:org_does_not_have_access)
      redirect_to organization_root_path and return
    end

    def set_current_hot_sheet_configuration
      @hot_sheet_configuration = current_organization.hot_sheet_configuration
      unless @hot_sheet_configuration.present?
        @hot_sheet_configuration = HotSheetConfiguration.new(organization_id: current_organization.id)
        @hot_sheet_configuration.set_default_attributes
      end
      @hot_sheet_configuration
    end

    def permitted_parameters
      params.require(:hot_sheet_configuration).permit([:is_enabled, :timezone_str, :send_hour])
    end
  end
end
