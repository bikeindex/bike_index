module Organized
  class HotSheetsController < Organized::BaseController
    before_action :ensure_admin!, except: [:show]
    before_action :ensure_access_to_hot_sheet!

    def show
      @day = (params[:day].present? ? params[:day] : Time.current).to_date
      @today = @day == Time.current.to_date
      @hot_sheet = HotSheet.for(current_organization, @day)
    end

    def edit
      @hot_sheet_configuration = current_organization.hot_sheet_configuration
      unless @hot_sheet_configuration.present?
        @hot_sheet_configuration = HotSheetConfiguration.new(organization_id: current_organization.id)
        @hot_sheet_configuration.set_default_attributes
      end
    end

    def update
    end

    private

    def ensure_access_to_hot_sheet!
      return unless ensure_current_organization!

      # ensure_admin! passes with superuser - this allow superuser to see even if org not enabled
      return true if current_user.superuser? || current_organization.enabled?("hot_sheet")

      flash[:error] = translation(:org_does_not_have_access)
      redirect_to organization_root_path and return
    end

    def permitted_parameters
      params.require(:hot_sheet_configuration).permit([:enabled])
    end
  end
end
