module Organized
  class ManageController < Organized::AdminController
    before_filter :assign_organization, only: [:index, :update, :locations]
    def index
      @organization.ensure_auto_user
    end

    def locations
    end

    def update
      if @organization.update_attributes(permitted_parameters)
        flash[:success] = "#{current_organization.name} updated successfully"
        redirect_path = params[:locations_page] ? locations_organization_manage_index_path(organization_id: current_organization.to_param) : current_index_path
        redirect_to redirect_path
      else
        @page_errors = @organization.errors
        flash[:error] = "We're sorry, we had trouble updating #{current_organization.name}"
        render :index
      end
    end

    def dev
    end

    def destroy
      organization_name = current_organization.name
      if current_organization.is_paid
        flash[:info] = "Please contact support@bikeindex.org to delete #{organization_name}"
        redirect_to current_index_path and return
      end
      notify_admins('organization_destroyed')
      current_organization.destroy
      flash[:info] = "Deleted #{organization_name}"
      redirect_to user_root_url
    end

    def landing
      render '/landing_pages/show'
    end

    private

    def assign_organization
      @organization = current_organization
    end

    def current_index_path
      organization_manage_index_path(organization_id: current_organization.to_param)
    end

    def permitted_parameters
      params.require(:organization).permit(:name, :website, :org_type, show_on_map_if_permitted,
                                           :embedable_user_email, paid_attributes,
                                           locations_attributes: permitted_locations_params)
    end

    def show_on_map_if_permitted
      current_organization.lock_show_on_map ? [] : [:show_on_map]
    end

    def paid_attributes
      current_organization.is_paid ? [:avatar] : []
    end

    def permitted_locations_params
      %w(name zipcode city state_id country_id street phone email id _destroy)
    end

    def notify_admins(type)
      AdminNotifier.new.for_organization(organization: current_organization, user: current_user, type: type)
    end
  end
end
