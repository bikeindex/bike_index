module Organized
  class ManageImpoundingsController < Organized::AdminController
    before_action :assign_organization

    # IDK, may want to render something here sometime
    def show
      redirect_to edit_organization_manage_impounding_path(organization_id: params[:organization_id])
    end

    def edit
      @organization.ensure_auto_user
      @page_title = "#{@organization.short_name} impound settings"
    end

    def update
      if @impound_configuration.update(permitted_parameters)
        flash[:success] = translation(:updated_successfully, org_name: current_organization.name)
        redirect_back(fallback_location: edit_organization_manage_impounding_path(organization_id: current_organization.to_param))
      else
        @page_errors = @impound_configuration.errors
        flash[:error] = translation(:could_not_update, org_name: current_organization.name)
        render :edit
      end
    end

    private

    def assign_organization
      @organization = current_organization
      @impound_configuration = @organization&.fetch_impound_configuration
      return true if @organization.enabled?("impound_bikes") || current_user.superuser?
      raise_do_not_have_access!
    end

    def permitted_parameters
      params.require(:impound_configuration).permit(:display_id_prefix, :public_view, :email, :expiration_period_days)
    end
  end
end
